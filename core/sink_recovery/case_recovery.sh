#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

MAX_RUNS=${MAX_RUNS:-5}
STAT_SEC=${STAT_SEC:-3}
# 恢复阶段让 test_rescue 全程健康：回放的目的地必须可用，
# 否则"恢复流程"自身又处在故障中，测不出恢复链路。
# 注意：这是恢复器的进程级设置，不会影响中断阶段。
RECOVERY_STAGES=${RECOVERY_STAGES:-"up:3600"}

RESCUE_DIR="./data/rescue"
LOG_FILE="./data/logs/wprescue.log"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

line_count() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

for cmd in wpadm wprescue; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

# 本地覆盖层可能来自旧版本（含已移除的配置段，如 [admin_api]），
# 会让 wparse/wpadm 直接报配置错误；用例不依赖它。
rm -f ./wparse.local.toml
echo "scan rescue dir: ${RESCUE_DIR}"
RUN_CNT=0
while [ "$RUN_CNT" -lt "$MAX_RUNS" ]; do
  if find "$RESCUE_DIR" -type f -name "*.dat" | grep -q .; then
    echo "[recovery] run $((RUN_CNT+1))..."
    # 前台运行，利用恢复器的空闲退出（默认 3s 无新文件自动退出）
    if ! WP_TEST_RESCUE_STAGES="$RECOVERY_STAGES" wprescue batch --stat "$STAT_SEC"; then
      echo "[recovery] wprescue exited with non-zero status"
      RUN_FAILED=1
    fi
    RUN_CNT=$((RUN_CNT+1))
  else
    echo "[recovery] no rescue .dat, stop loop"
    break
  fi
done
echo "[recovery] finished runs=$RUN_CNT (max=$MAX_RUNS)"

echo "rescue data left:"
find "$RESCUE_DIR" -type f -name "*.dat"

wpadm data stat

# ---------------- 断言 ----------------

# 1) 回放必须真的发生，并且整份救急文件被读完
grep -q "recover file:" "$LOG_FILE" \
    || die "wprescue.log: no 'recover file:'; nothing was replayed"
grep -q "recover end! clean file" "$LOG_FILE" \
    || die "wprescue.log: no 'recover end! clean file'; the rescue file was not consumed"

# 2) 回放期间不允许出现发送失败（恢复阶段的目标 sink 是健康的）
if grep -q "recover send failed" "$LOG_FILE"; then
    grep "recover send failed" "$LOG_FILE" | head -5 >&2
    die "wprescue.log: replay hit sink send failures; see ${LOG_FILE}"
fi

if [ "${RUN_FAILED:-0}" -ne 0 ]; then
    die "wprescue failed; see ${LOG_FILE}"
fi

# 3) 救急文件必须被消费掉
if find "$RESCUE_DIR" -type f -name "*.dat" | grep -q .; then
    find "$RESCUE_DIR" -type f -name "*.dat" >&2
    die "rescue .dat files were not consumed"
fi

# 4) 守恒：回放完成后所有记录都应落在业务 sink 里
INPUT=$(line_count ./data/in_dat/gen.dat)
BENCH=$(line_count ./data/out_dat/benchmark.dat)
OTHER=$(line_count ./data/out_dat/example.dat)
INFRA=$(( $(line_count ./data/out_dat/miss.dat) + $(line_count ./data/out_dat/residue.dat) + $(line_count ./data/out_dat/error.dat) ))

echo "check: input=${INPUT} benchmark=${BENCH} example=${OTHER} infra=${INFRA}"

[ "$INPUT" -gt 0 ] || die "input is empty"
[ -s ./data/out_dat/benchmark.dat ] || die "expected recovered output in ./data/out_dat/benchmark.dat"

TOTAL=$(( BENCH + OTHER + INFRA ))
[ "$TOTAL" -eq "$INPUT" ] \
    || die "record conservation broken after replay: ${TOTAL} != ${INPUT} (benchmark=${BENCH} example=${OTHER} infra=${INFRA})"

# 5) 分布/比例校验：按 topology 里的 expect 配置给出 validate: PASS/FAIL
#    守恒断言保证"没丢"，这里额外保证"分到对的组"。
wpadm data validate || die "distribution check failed; see the table above"

echo "OK: rescue data replayed into the target sink, ${INPUT} record(s) accounted for"
