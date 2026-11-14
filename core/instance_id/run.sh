#!/usr/bin/env bash
set -euo pipefail

# 实例号（WP_INS_ID）与事件 ID 布局用例
#
# 验证 `wp_event_id = 秒(32) | 实例号(10) | 每秒计数器(22)`：
#   - 实例号来自 `WP_INS_ID`，解析路径与 `WP_GLOBAL_TAGS` 完全一致
#     （进程环境优先 → work root 的 .env → .warp_parse/.env）
#   - 不同实例号的 ID 落在互不相交的 lane 段，因此跨实例永不重复
#   - 非法实例号必须启动失败，不能静默回退到默认值 100

cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数
LINE_CNT=${LINE_CNT:-300}
STAT_SEC=${STAT_SEC:-1}

# 布局常量，须与 wp-model-core::event_id 保持一致
LANE_DIV=4194304    # 2^22：每秒计数器位宽
LANE_MOD=1024       # 2^10：实例号位宽
SECS_DIV=4294967296 # 2^32：秒级时间戳占高 32 位
INS_ID_BASE=100     # 实例号起点

OUT_FILE="./out/default.dat"
LOG_FILE="./data/logs/wparse.log"
ENV_FILE="./.env"
ERR_FILE="./.run/instance_id_err.txt"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

for cmd in wparse wpgen wpadm bc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "命令不存在: $cmd"
    fi
done

# ---------------- 工具函数 ----------------

extract_ids() {
    grep -o 'wp_event_id: "[0-9]*"' "$OUT_FILE" | grep -o '[0-9]*'
}

reset_case() {
    unset WP_INS_ID WP_GLOBAL_TAGS || true
    rm -f "$ENV_FILE"
    rm -f "$OUT_FILE"
    wpadm check >/dev/null 2>&1 || true
    wpadm data clean >/dev/null 2>&1 || true
    wpgen data clean >/dev/null 2>&1 || true
}

gen_samples() {
    wpgen sample -n "$LINE_CNT" --stat 100 >/dev/null
}

run_batch() { # run_batch <label>
    local label=$1
    if ! wparse batch --stat "$STAT_SEC" -n "$LINE_CNT" >/dev/null 2>&1; then
        echo "---- ${LOG_FILE} (tail) ----" >&2
        tail -25 "$LOG_FILE" >&2 || true
        die "[$label] wparse batch 退出码非 0"
    fi
    [ -s "$OUT_FILE" ] || die "[$label] ${OUT_FILE} 不存在或为空"
}

assert_has_id_per_record() { # assert_has_id_per_record <label>
    local label=$1 lines ids
    lines=$(grep -c . "$OUT_FILE" || true)
    ids=$(extract_ids | wc -l | tr -d ' ')
    [ "$lines" -gt 0 ] || die "[$label] 输出为空"
    [ "$lines" -eq "$ids" ] \
        || die "[$label] 每条记录都必须带 wp_event_id: lines=${lines} ids=${ids}"
}

assert_unique() { # assert_unique <label>
    local label=$1 total uniq
    total=$(extract_ids | wc -l | tr -d ' ')
    uniq=$(extract_ids | sort -u | wc -l | tr -d ' ')
    [ "$total" -gt 0 ] || die "[$label] 没有取到任何 wp_event_id"
    [ "$total" -eq "$uniq" ] \
        || die "[$label] wp_event_id 出现重复: total=${total} unique=${uniq}"
}

assert_lane() { # assert_lane <label> <expected_lane>
    local label=$1 expected=$2 ids count prog bad id
    ids=$(extract_ids)
    count=$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] || die "[$label] 没有取到任何 wp_event_id"

    # 19 位整数超出 awk/double 精度，用 bc 逐个校验
    prog="bad=0;"
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        prog="${prog}
if ((${id} / ${LANE_DIV}) % ${LANE_MOD} != ${expected}) bad=bad+1;"
    done <<< "$ids"
    bad=$(printf '%s\nbad\n' "$prog" | bc)
    [ "$bad" -eq 0 ] \
        || die "[$label] lane 段不符: ${bad}/${count} 条记录的 lane != ${expected}"
}

assert_secs_is_now() { # assert_secs_is_now <label>
    local label=$1 id secs now
    now=$(date +%s)
    id=$(extract_ids | head -1)
    secs=$(echo "$id / ${SECS_DIV}" | bc)
    [ "$secs" -ge $((now - 120)) ] || die "[$label] 秒段过旧: secs=${secs} now=${now}"
    [ "$secs" -le $((now + 10)) ] || die "[$label] 秒段过于超前: secs=${secs} now=${now}"
}

expect_startup_failure() { # expect_startup_failure <ins_id>
    local bad=$1 rc
    mkdir -p "$(dirname "$ERR_FILE")"
    set +e
    WP_INS_ID="$bad" wparse batch -n 1 >"$ERR_FILE" 2>&1
    rc=$?
    set -e
    [ "$rc" -ne 0 ] || die "WP_INS_ID=${bad} 竟然启动成功（应当拒绝）"
    grep -q "WP_INS_ID" "$ERR_FILE" \
        || die "WP_INS_ID=${bad} 失败但错误信息未提到 WP_INS_ID"
    echo "   WP_INS_ID=${bad} -> 退出码 ${rc}（已拒绝）"
}

# ---------------- 用例步骤 ----------------

echo "1> 默认实例号（未设置 WP_INS_ID → ${INS_ID_BASE}，lane=0）"
reset_case
gen_samples
run_batch default
assert_has_id_per_record default
assert_lane default 0
assert_unique default
assert_secs_is_now default
echo "   lane=0, $(extract_ids | wc -l | tr -d ' ') 条"

echo "2> 进程环境变量 WP_INS_ID=101 → lane=1"
reset_case
gen_samples
WP_INS_ID=101 run_batch env
assert_lane env 1
assert_unique env
assert_has_id_per_record env

echo "3> .env 提供 WP_INS_ID=102 → lane=2（与 WP_GLOBAL_TAGS 同一套解析逻辑）"
reset_case
gen_samples
echo "WP_INS_ID=102" >"$ENV_FILE"
run_batch dotenv
assert_lane dotenv 2
assert_unique dotenv

echo "4> 进程环境优先于 .env（.env=102 / 进程=103 → lane=3）"
reset_case
gen_samples
echo "WP_INS_ID=102" >"$ENV_FILE"
WP_INS_ID=103 run_batch env-wins
assert_lane env-wins 3

echo "5> WP_GLOBAL_TAGS 与 WP_INS_ID 共用同一个 .env"
reset_case
gen_samples
cat >"$ENV_FILE" <<'ENV_EOF'
WP_INS_ID=100
WP_GLOBAL_TAGS="owner_id=team-a,from_zone=global_zone"
ENV_EOF
run_batch global-tags
assert_lane global-tags 0
lines=$(grep -c . "$OUT_FILE" || true)
owner=$(grep -c 'owner_id: "team-a"' "$OUT_FILE" || true)
zone=$(grep -c 'from_zone: "global_zone"' "$OUT_FILE" || true)
[ "$owner" -eq "$lines" ] || die "[global-tags] owner_id 未覆盖到每条记录: ${owner}/${lines}"
[ "$zone" -eq "$lines" ] || die "[global-tags] from_zone 未覆盖到每条记录: ${zone}/${lines}"
echo "   owner_id/from_zone 覆盖 ${lines} 条"

echo "6> 非法 WP_INS_ID 必须启动失败（不得静默回退到默认 lane）"
reset_case
gen_samples
expect_startup_failure 99     # 低于起点
expect_startup_failure 0      # 低于起点
expect_startup_failure 1124   # 超出 10 位 lane
expect_startup_failure abc    # 非数字

rm -f "$ENV_FILE" "$ERR_FILE"

echo "OK: 实例号隔离与事件 ID 布局验证通过（lane 分段、唯一性、.env 链路、非法值拒绝）"
