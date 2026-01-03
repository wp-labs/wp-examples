#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 默认参数
SPEED_MAX="${1:-0}"
WORKER_CNT="6"
LINE_CNT=20000000

# 验证命令存在
for cmd in wparse wpgen wproj; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done


# 初始化配置
wproj check
wproj data clean
wpgen data clean

echo "LINE_CNT=$LINE_CNT, SPEED_MAX=$SPEED_MAX"

# 启动 daemon
echo "Starting daemon mode"
wparse daemon  --stat 1 -w "$WORKER_CNT" -p &

# 等待 PID 文件出现
for i in {1..50}; do
    test -f ./.run/wparse.pid && break
    sleep 0.1
done
sleep 1

# 生成数据
echo "Generating sample data"
wpgen sample -n "$LINE_CNT" -s "$SPEED_MAX" --stat 2 --wpl ../../models/wpl

# 停止 daemon
if [ -f ./.run/wparse.pid ]; then
    cat ./.run/wparse.pid | xargs kill || true
fi
sleep 1

# 显示统计
wproj data stat
