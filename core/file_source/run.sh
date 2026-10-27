#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-1}

# 实例级全局 tag（等价于 work_root/.env 里的 WP_GLOBAL_TAGS）：
# - tenant_id 是模型里不存在的新字段，验证 OML 变换后仍会补盖；
# - from_zone 覆盖 OML 模型里写死的 work_zone，验证优先级高于模型输出；
# - benchmark2 的 sink tags 里也写了 tenant_id，验证全局值优先于 sink tag。
export WP_GLOBAL_TAGS="${WP_GLOBAL_TAGS:-tenant_id=1000000000000000001,from_zone=global_zone}"

# benchmark1 的输出文件名来自 SEC_DATA_1（见 .warp_parse/sec_key.toml）
BENCH1_OUT=${BENCH1_OUT:-data/out_dat/sec_kv1.dat}
BENCH2_OUT=${BENCH2_OUT:-data/out_dat/benchmark_kv2.dat}

# 验证必要的命令存在
for cmd in wparse wpgen wpadm; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

echo "1> init conf & data"
wpadm check || true
wpadm data clean || true
wpgen data clean || true

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"
wpgen rule -n "$LINE_CNT" --stat "$STAT_SEC"


echo "3> start wparse work"
if ! wparse batch --stat "$STAT_SEC" -p ; then
    echo "wparse work failed. check ./data/logs/wparse.log"
    exit 1
fi

echo "4> validate sinks"
wpadm data stat
wpadm data validate

echo "5> validate global tags (WP_GLOBAL_TAGS)"
fail=0
for f in "$BENCH1_OUT" "$BENCH2_OUT"; do
    if [ ! -s "$f" ]; then
        echo "  [FAIL] $f not found or empty"
        fail=1
        continue
    fi
    total=$(grep -c . "$f")
    # 每条记录恰好一个 tenant_id，且取实例级全局值
    tenant_lines=$(grep -c 'tenant_id' "$f" || true)
    tenant_occ=$(grep -o 'tenant_id' "$f" | wc -l | tr -d ' ' || true)
    tenant_hit=$(grep -c 'tenant_id: "1000000000000000001"' "$f" || true)
    # 全局 tag 覆盖模型里写死的 work_zone
    zone_hit=$(grep -c 'from_zone: "global_zone"' "$f" || true)
    if [ "$tenant_lines" -eq "$total" ] && [ "$tenant_occ" -eq "$total" ] \
        && [ "$tenant_hit" -eq "$total" ] && [ "$zone_hit" -eq "$total" ] \
        && ! grep -q 'work_zone' "$f" && ! grep -q 'from-sink' "$f"; then
        echo "  [OK] $f: $total records carry tenant_id/from_zone"
    else
        echo "  [FAIL] $f: unexpected global tag fields (total=$total lines=$tenant_lines occ=$tenant_occ hit=$tenant_hit zone=$zone_hit)"
        fail=1
    fi
done

# 不冲突的 sink tag 应保留，且只出现在 benchmark2
if [ -s "$BENCH2_OUT" ]; then
    env_hit=$(grep -c 'env: "dev"' "$BENCH2_OUT" || true)
    if [ "$env_hit" -gt 0 ] && ! grep -q 'env:' "$BENCH1_OUT"; then
        echo "  [OK] sink tag env: dev kept on benchmark2 only"
    else
        echo "  [FAIL] sink tag env not handled as expected"
        fail=1
    fi
fi

if [ "$fail" -ne 0 ]; then
    echo "global tag validation failed"
    exit 1
fi
echo "global tag validation passed"
