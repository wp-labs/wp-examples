#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 输入规模：conf/wparse.toml 的 [performance] rate_limit_rps = 2000，因此耗时 ≈ LINE_CNT/2000 秒
LINE_CNT=${LINE_CNT:-16000}
GEN_SPEED=${GEN_SPEED:-10000}
STAT_SEC=${STAT_SEC:-3}
# test_rescue 的健康阶段表（秒）：健康 1s -> 故障 4s -> 之后视为健康。
# 故障期足够长，可以观察到"熔断打开 -> 冷却后探测 -> 探测成功自动恢复"的完整过程。
RESCUE_STAGES=${RESCUE_STAGES:-"up:1,down:4"}

RESCUE_DIR="./data/rescue"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

line_count() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }

rescue_file_count() {
    find "$RESCUE_DIR" -type f \( -name '*.dat' -o -name '*.dat.lock' \) 2>/dev/null | wc -l | tr -d ' '
}

# 日志可能因体积触发 gzip 轮转（10MB），断言要覆盖全部分片
log_grep() {
    local pat=$1 f
    for f in data/logs/wparse.log*; do
        [ -f "$f" ] || continue
        case "$f" in
            *.gz) zgrep -q "$pat" "$f" 2>/dev/null && return 0 ;;
            *) grep -q "$pat" "$f" 2>/dev/null && return 0 ;;
        esac
    done
    return 1
}

# 故障期次数：每个故障期一行 "recovered from send failures ..."
log_recovery_count() {
    local n=0 f v reader
    for f in data/logs/wparse.log*; do
        [ -f "$f" ] || continue
        case "$f" in
            *.gz) reader=(gzip -dc) ;;
            *)    reader=(cat) ;;
        esac
        v=$("${reader[@]}" "$f" 2>/dev/null | grep -c 'recovered from send failures' || true)
        n=$(( n + ${v:-0} ))
    done
    echo "$n"
}

# 丢弃总数：恢复汇总（每个故障期一条，权威）与累计值取大。
# - 恢复汇总：recovered from send failures (drop_when_error): dropped N record(s) since ...
# - 累计值（每轮统计刷新）：sink '...' dropped: window=N total=M
# - 累计值（首次真实失败 / 熔断跳闸时各一条，之后每 60s 一条）：
#     drop_when_error: dropped N record(s), total M
#     drop_when_error: breaker open, skipped N record(s), total M
# 只认恢复汇总时，sink 一直没恢复就恒为 0，明明丢了上万条也看不出来；
# 累计值在未恢复时依然会刷新。本用例只有一个 sink，故取最大值。
log_dropped_total() {
    local recovered=0 cumulative=0 f v reader
    for f in data/logs/wparse.log*; do
        [ -f "$f" ] || continue
        case "$f" in
            *.gz) reader=(gzip -dc) ;;
            *)    reader=(cat) ;;
        esac

        v=$("${reader[@]}" "$f" 2>/dev/null \
            | grep -o 'recovered from send failures (drop_when_error): dropped [0-9]* record(s) since' \
            | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}' || true)
        recovered=$(( recovered + ${v:-0} ))

        v=$("${reader[@]}" "$f" 2>/dev/null \
            | grep -oE 'dropped: window=[0-9]+ total=[0-9]+|record\(s\), total [0-9]+' \
            | grep -oE '[0-9]+$' | sort -n | tail -1 || true)
        if [ -n "${v:-}" ] && [ "$v" -gt "$cumulative" ]; then
            cumulative=$v
        fi
    done
    if [ "$cumulative" -gt "$recovered" ]; then
        recovered=$cumulative
    fi
    echo "$recovered"
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
mkdir -p "$RESCUE_DIR"

echo "1> gen sample data: ${LINE_CNT} lines"
wpgen sample -n "$LINE_CNT" -s "$GEN_SPEED" --stat 100

echo "2> run wparse with drop_when_error (schedule: ${RESCUE_STAGES})"
WP_TEST_RESCUE_STAGES="$RESCUE_STAGES" wparse batch --stat "$STAT_SEC" --print_stat

wpadm data stat

# ---------------- 断言 ----------------

# 1) drop_when_error 不允许产生救援文件
RESCUE_FILES=$(rescue_file_count)
if [ "$RESCUE_FILES" -ne 0 ]; then
    find "$RESCUE_DIR" -type f >&2
    die "drop_when_error must not create rescue files, found ${RESCUE_FILES}"
fi

# 2) 坏链路期间必须熔断（跳过下发），而不是每个批次都去撞 sink
log_grep "breaker open, skipped" \
    || die "wparse.log: no 'breaker open, skipped' line; the sink kept retrying while failing
  hint: 需要 wp-motor >= v1.37.0（该 WARN 每故障期输出一次，旧版本会被 60s 限流吞掉）"

# 3) 链路恢复后必须自动复位
RECOVERY_LINES=$(log_recovery_count)
if [ "$RECOVERY_LINES" -eq 0 ]; then
    die "wparse.log: sink never recovered from the outage (no 'recovered from send failures')"
fi
# 每个故障期一行 "recovered ... dropped N record(s) since ..."，累加即为总丢弃数；
# 没有恢复汇总时回落到累计值（见 log_dropped_total）。
DROPPED=$(log_dropped_total)

INPUT=$(line_count ./data/in_dat/gen.dat)
BENCH=$(line_count ./data/out_dat/benchmark.dat)
OTHER=$(line_count ./data/out_dat/example.dat)
INFRA=$(( $(line_count ./data/out_dat/miss.dat) + $(line_count ./data/out_dat/residue.dat) + $(line_count ./data/out_dat/error.dat) ))

echo "check: input=${INPUT} benchmark=${BENCH} example=${OTHER} infra=${INFRA} dropped=${DROPPED} recoveries=${RECOVERY_LINES}"

[ "$INPUT" -gt 0 ] || die "input is empty"
[ "$BENCH" -gt 0 ] || die "sink wrote nothing after recovery"
[ "$DROPPED" -gt 0 ] || die "expected dropped records during the outage, got 0"

# 4) 守恒：丢掉的记录不再进任何文件，未被丢的记录必须全部落盘
TOTAL=$(( BENCH + OTHER + INFRA + DROPPED ))
[ "$TOTAL" -eq "$INPUT" ] \
    || die "record conservation broken: ${TOTAL} != ${INPUT} (benchmark=${BENCH} example=${OTHER} infra=${INFRA} dropped=${DROPPED})"

echo "OK: breaker suppressed failed sends, dropped ${DROPPED} record(s), sink recovered ${RECOVERY_LINES} time(s)"
