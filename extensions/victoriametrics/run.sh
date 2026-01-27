#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}

# 验证必要的命令存在
for cmd in wparse wpgen wproj curl; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

echo "1> init conf & data"
wproj data clean || true
rm -f prometheus_monitor.dat

echo "2> start wparse daemon (syslog receiver)"
wparse daemon --stat 2 -p &
echo "Waiting for wparse (syslog:1514) and prometheus exporter to start..."
sleep 3

echo "3> gen sample data (send to syslog) - press Ctrl+C to stop"

# 设置信号处理，捕获 SIGINT 和 SIGTERM
trap 'echo "Received stop signal, exiting loop..."; break' INT TERM

# 循环执行 wpgen sample
while true; do
    wpgen sample -n "$LINE_CNT" --stat 1 -p
    sleep "$STAT_SEC"
done

echo "4> stop wparse"
# 发送 SIGTERM 并等待进程退出
if [ -f ./.run/wparse.pid ]; then
    pid=$(cat ./.run/wparse.pid)
    kill -TERM "$pid" 2>/dev/null || true
fi
sleep 5

wproj data stat
wproj data validate --input-cnt "$LINE_CNT"
