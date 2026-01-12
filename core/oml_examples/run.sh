#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-2}
GEN_STAT_SEC=${GEN_STAT_SEC:-3}

# 验证必要的命令存在
for cmd in wparse wpgen wproj; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

echo "1> init conf & data"
# 初始化配置与数据目录
wproj check
wproj data clean || true
wpgen data clean || true

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT" --stat "$GEN_STAT_SEC"

echo "3> start wparse work"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
    echo "wparse work failed. check ./logs/wparse.log"
    exit 1
fi

wproj data stat
wproj data validate
