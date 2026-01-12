#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

wproj check
wproj data clean


LINE_CNT=10000
SPEED_MAX=5000
echo "gen  sample data"
wpgen sample  -n $LINE_CNT -s $SPEED_MAX

sleep 3

echo "start work (no print_stat)"
wparse batch --stat 2
sleep 2

wproj data stat
wproj data validate
