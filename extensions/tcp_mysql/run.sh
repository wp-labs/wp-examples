#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

wproj check
wproj data clean

echo "start work (no print_stat)"
wparse deamon --stat 5 -w 8 -p &
# 等待 PID 文件出现
for i in {1..50}; do
    test -f ./.run/wparse.pid && break
    sleep 0.1
done
sleep 3

LINE_CNT=100
SPEED_MAX=5000
echo "1> gen  sample data"
wpgen sample  -n $LINE_CNT -s $SPEED_MAX --stat 10

sleep 3
if [ -f ./.run/wparse.pid ]; then
    kill $(cat ./.run/wparse.pid) || true
fi
sleep 3

wproj data stat
wproj data validate
