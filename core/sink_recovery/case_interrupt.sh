#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 输入规模：conf/wparse.toml 的 [performance] rate_limit_rps = 1000，
# 所以本阶段耗时 ≈ LINE_CNT/1000 秒，需要明显长于故障窗口 + 重连周期(5s)。
LINE_CNT=${LINE_CNT:-12000}
GEN_SPEED=${GEN_SPEED:-10000}
STAT_SEC=${STAT_SEC:-3}
# test_rescue 的健康阶段表（秒）：健康 2s -> 故障 3s -> 之后视为健康。
# 故障期间写失败会切入救援文件；故障结束后维护线程重连成功，救援文件回收成 .dat。
RESCUE_STAGES=${RESCUE_STAGES:-"up:2,down:3"}

RESCUE_DIR="./data/rescue"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

line_count() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

rescue_line_count() {
    local total=0 f n
    while IFS= read -r -d '' f; do
        n=$(wc -l < "$f" | tr -d ' ')
        total=$((total + n))
    done < <(find "$RESCUE_DIR" -type f \( -name '*.dat' -o -name '*.dat.lock' \) -print0 2>/dev/null)
    echo "$total"
}

for cmd in wparse wpgen wpadm; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

# 本地覆盖层可能来自旧版本（含已移除的配置段，如 [admin_api]），
# 会让 wparse/wpadm 直接报配置错误；用例不依赖它。
rm -f ./wparse.local.toml
wpadm check
wpadm init --mode data
wpadm data clean
wpgen data clean
rm -rf "$RESCUE_DIR"
rm -f ./rescue/recover.lock

echo "1> gen sample data: ${LINE_CNT} lines"
wpgen sample -n "$LINE_CNT" -s "$GEN_SPEED" --stat 100

echo "2> run wparse (test_rescue schedule: ${RESCUE_STAGES})"
WP_TEST_RESCUE_STAGES="$RESCUE_STAGES" wparse batch --stat "$STAT_SEC" --print_stat

echo "3> rescue files in ${RESCUE_DIR}:"
find "$RESCUE_DIR" -type f | sort

wpadm data stat

# ---------------- 断言 ----------------

# 日志可能按大小轮转，把当前日志和归档日志拼成一份再断言
LOG_VIEW=$(mktemp)
trap 'rm -f "$LOG_VIEW"' EXIT
cat ./data/logs/wparse.log >> "$LOG_VIEW" 2>/dev/null || true
for f in ./data/logs/wparse.log.*.gz; do
    [ -e "$f" ] || continue
    gzip -dc "$f" >> "$LOG_VIEW" 2>/dev/null || true
done
log_has() { grep -q "$1" "$LOG_VIEW"; }

RESCUE=$(rescue_line_count)
[ "$RESCUE" -gt 0 ] || die "no rescue data captured; the fault window did not take effect
  hint: 用例需要 wp-motor >= v1.37.0（WP_TEST_RESCUE_STAGES 在该版本引入），
        旧二进制会忽略该变量，退回默认的 2s/2s 时序"

# 故障窗口起止：切到救援文件 / 重连成功 / 救援文件回收
log_has "on rescue" \
    || die "wparse.log: missing 'on rescue'; the sink never switched to a rescue file"
log_has "reconnect success" \
    || die "wparse.log: missing 'reconnect success'; the sink never came back"
log_has "rescue file finalized" \
    || die "wparse.log: missing 'rescue file finalized'; the rescue file was not reclaimed"

# 只有去掉 .lock 的救援文件才会被恢复阶段消费，中断阶段必须在健康状态下结束
if find "$RESCUE_DIR" -type f -name '*.dat.lock' | grep -q .; then
    find "$RESCUE_DIR" -type f -name '*.dat.lock' >&2
    die "rescue files are still locked; the interrupt phase must end with a healthy sink"
fi

INPUT=$(line_count ./data/in_dat/gen.dat)
BENCH=$(line_count ./data/out_dat/benchmark.dat)
OTHER=$(line_count ./data/out_dat/example.dat)
INFRA=$(( $(line_count ./data/out_dat/miss.dat) + $(line_count ./data/out_dat/residue.dat) + $(line_count ./data/out_dat/error.dat) ))

echo "check: input=${INPUT} benchmark=${BENCH} example=${OTHER} infra=${INFRA} rescue=${RESCUE}"

[ "$INPUT" -gt 0 ] || die "input is empty"
[ "$BENCH" -gt 0 ] || die "benchmark sink wrote nothing before the fault window"

# 守恒：每条记录要么进了业务 sink，要么留在救援文件里
TOTAL=$(( BENCH + OTHER + INFRA + RESCUE ))
[ "$TOTAL" -eq "$INPUT" ] \
    || die "record conservation broken: ${TOTAL} != ${INPUT} (benchmark=${BENCH} example=${OTHER} infra=${INFRA} rescue=${RESCUE})"

echo "OK: ${RESCUE} record(s) parked in rescue files, ${BENCH} record(s) delivered before/after the outage"
