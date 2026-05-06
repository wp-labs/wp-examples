#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 验证必要的命令存在
for cmd in wparse wpgen wproj; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

wproj check
wproj init --mode data
wproj data clean
wpgen data clean

echo "1> gen sample data"
wpgen sample -n 10000 -s 10000 --stat 100

echo "2> start wparse work"
wparse batch --stat 10 --print_stat

echo "3> rescue data:"
find ./data/rescue/ -name "*.dat"

wproj data stat

# 中断阶段只验证救急文件已生成；此时业务 sink 输出仍是中间态，不做比例校验。
if ! find ./data/rescue/ -type f -name "*.dat" | grep -q .; then
    echo "Expected rescue .dat files, but none were generated"
    exit 1
fi
