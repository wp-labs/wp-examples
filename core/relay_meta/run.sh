#!/usr/bin/env bash
set -euo pipefail

# 接力链路（A → B）验证 wp_* meta 的保留 / 覆盖语义。
#
#   A：file_src → 解析 → file_json_sink，输出 JSON Lines（含 wp_event_id /
#      wp_src_key / wp_event_md5）
#   B：file_src 读 A 的输出 → 规则用 json(...) 把上游 wp_* 当普通字段提取
#      → file_proto_sink
#
# 默认（四个开关都不配）B 应沿用 A 的 ID / source / md5；把对应开关设为
# false 则退回「本阶段重新标识」。

cd "$(dirname "${BASH_SOURCE[0]}")"

LINE_CNT=${LINE_CNT:-20}
STAT_SEC=${STAT_SEC:-1}
A_OUT="./out/relay.json"
B_OUT="./stage_b/out/b.dat"
B_IN="./stage_b/data/in_dat/relay.json"

# 与 wp-model-core::event_id 一致的布局常量
LANE_DIV=4194304   # 2^22
LANE_MOD=1024      # 2^10

die() { echo "FAIL: $*" >&2; exit 1; }

for cmd in wparse wpgen wpadm bc; do
    command -v "$cmd" >/dev/null 2>&1 || die "命令不存在: $cmd"
done

# ---------------- 阶段驱动 ----------------

reset_a() {
    unset WP_INS_ID || true
    rm -f "$A_OUT"
    wpadm check >/dev/null 2>&1 || true
    wpadm data clean >/dev/null 2>&1 || true
    wpgen data clean >/dev/null 2>&1 || true
}

run_a() {
    wpgen sample -n "$LINE_CNT" --stat 100 >/dev/null
    if ! wparse batch --stat "$STAT_SEC" -n "$LINE_CNT" >/dev/null 2>&1; then
        tail -20 ./data/logs/wparse.log >&2 || true
        die "阶段 A 运行失败"
    fi
    [ -s "$A_OUT" ] || die "阶段 A 没有产出 $A_OUT"
}

reset_b() {
    rm -f "$B_OUT"
    ( cd stage_b && wpadm check >/dev/null 2>&1 && wpadm data clean >/dev/null 2>&1 ) || true
    mkdir -p "$(dirname "$B_IN")"
    cp "$A_OUT" "$B_IN"
}

run_b() { # run_b [VAR=value ...]
    if ! ( cd stage_b && env WP_INS_ID=101 "$@" wparse batch --stat "$STAT_SEC" -n "$LINE_CNT" >/dev/null 2>&1 ); then
        echo "---- stage_b 日志 ----" >&2
        tail -20 ./stage_b/data/logs/wparse.log >&2 || true
        die "阶段 B 运行失败"
    fi
    [ -s "$B_OUT" ] || die "阶段 B 没有产出 $B_OUT"
}

# ---------------- 取值工具 ----------------

# A 的 JSON Lines → 每行一个字段值
a_values() { grep -o "\"$1\":\"[^\"]*\"" "$A_OUT" | sed "s/.*:\"//; s/\"$//"; }
# B 的 proto 文本 → 每行一个字段值
b_values() { grep -o "$1: \"[^\"]*\"" "$B_OUT" | sed "s/.*: \"//; s/\"$//"; }

a_ids()     { a_values wp_event_id; }
b_ids()     { b_values wp_event_id; }
a_src()     { a_values wp_src_key; }
b_src()     { b_values wp_src_key; }
a_md5()     { a_values wp_event_md5; }
b_md5()     { b_values wp_event_md5; }

assert_field_per_record() { # assert_field_per_record <阶段名> <字段名> <文件> <取值函数>
    local stage=$1 field=$2 file=$3 getter=$4 lines count
    lines=$(grep -c . "$file" || true)
    count=$("$getter" | wc -l | tr -d ' ')
    [ "$lines" -gt 0 ] || die "[$stage] 输出为空"
    [ "$count" -eq "$lines" ] \
        || die "[$stage] 每条记录应恰好一个 $field: lines=$lines 命中=$count（出现重复字段？）"
}

same_set() { # same_set <阶段名> <A取值函数> <B取值函数>
    local stage=$1 left=$2 right=$3
    [ "$("$left" | sort -u)" = "$("$right" | sort -u)" ] \
        || die "[$stage] 期望沿用上游值，实际不一致"
}

disjoint_set() { # disjoint_set <阶段名> <A取值函数> <B取值函数>
    local stage=$1 left=$2 right=$3 overlap
    overlap=$(comm -12 <("$left" | sort -u) <("$right" | sort -u) | wc -l | tr -d ' ')
    [ "$overlap" -eq 0 ] || die "[$stage] 期望与上游不相交，实际有 $overlap 个重叠值"
}

assert_lane() { # assert_lane <阶段名> <期望 lane>
    local stage=$1 expected=$2 ids count prog bad id
    ids=$(b_ids)
    count=$(printf '%s\n' "$ids" | sed '/^$/d' | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] || die "[$stage] 没有取到 wp_event_id"
    prog="bad=0;"
    while IFS= read -r id; do
        [ -n "$id" ] || continue
        prog="${prog}
if ((${id} / ${LANE_DIV}) % ${LANE_MOD} != ${expected}) bad=bad+1;"
    done <<< "$ids"
    bad=$(printf '%s\nbad\n' "$prog" | bc)
    [ "$bad" -eq 0 ] || die "[$stage] ${bad}/${count} 条记录的 lane != ${expected}"
}

# ---------------- 用例步骤 ----------------

echo "1> 阶段 A：解析并输出 JSON Lines（gen_event_md5 = true）"
reset_a
run_a
RECORDS=$(grep -c . "$A_OUT" || true)
echo "   A 产出 ${RECORDS} 条，字段：$(a_ids | sed -n '1p') … "
[ "$RECORDS" -gt 0 ] || die "阶段 A 无输出"

echo "2> 阶段 B（默认：四个开关都不配 → 沿用上游）"
reset_b
run_b
assert_field_per_record B wp_event_id "$B_OUT" b_ids
assert_field_per_record B wp_src_key "$B_OUT" b_src
assert_field_per_record B wp_event_md5 "$B_OUT" b_md5
same_set "B/event_id" a_ids b_ids
same_set "B/src_key" a_src b_src
same_set "B/md5" a_md5 b_md5
[ "$(b_src | sort -u)" = "file_1" ] \
    || die "B 的 wp_src_key 应为上游的 file_1，实际：$(b_src | sort -u)"
echo "   B 沿用上游 event_id / src_key=file_1 / md5，且每条记录各只有一个"

echo "3> UPSTREAM_EVENT_ID_KEEP=false：本阶段重新发号"
reset_b
run_b UPSTREAM_EVENT_ID_KEEP=false
assert_field_per_record B wp_event_id "$B_OUT" b_ids
disjoint_set "B/event_id(keep=false)" a_ids b_ids
assert_lane "B/event_id(keep=false)" 1
echo "   ID 与上游不相交，lane=1（WP_INS_ID=101）"

echo "4> UPSTREAM_SRC_KEEP=false：用本实例的 source 覆盖"
reset_b
run_b UPSTREAM_SRC_KEEP=false
assert_field_per_record B wp_src_key "$B_OUT" b_src
[ "$(b_src | sort -u)" = "file_b" ] \
    || die "期望 wp_src_key=file_b，实际：$(b_src | sort -u)"
# 只影响 source，ID 仍然沿用
same_set "B/event_id(仅 src 覆盖)" a_ids b_ids
echo "   wp_src_key=file_b，wp_event_id 仍沿用上游"

echo "5> UPSTREAM_EVENT_MD5_KEEP=false：用本实例收到的 payload 重算"
reset_b
run_b UPSTREAM_EVENT_MD5_KEEP=false
assert_field_per_record B wp_event_md5 "$B_OUT" b_md5
disjoint_set "B/md5(keep=false)" a_md5 b_md5
echo "   md5 与上游不同（B 重算了 A 那一行 JSON 的 md5）"

echo "OK: 接力链路 wp_* meta 语义验证通过（沿用 / 覆盖 / 单字段）"
