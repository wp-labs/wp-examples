#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 初始化与构建：基准测试默认使用 release，且在复现问题时保留已有 conf
core_usecase_bootstrap "${1:-debug}" skip_clean wparse wpgen wproj

wproj check
wproj data clean
wpgen data clean

# 预清理：释放默认 syslog TCP 端口（防止上次遗留进程占用 1514）
if command -v lsof >/dev/null 2>&1; then
  lsof -t -nP -iTCP:1514 2>/dev/null | xargs -r kill -9 || true
fi

echo "2> start work (no print_stat)"
wparse deamon --stat 5 -w 8 &
wait_for_pid_file ./.run/wparse.pid || true
sleep 3;

LINE_CNT=10000
SPEED_MAX=5000
echo "1> gen  sample data"
wpgen sample  -n $LINE_CNT -s $SPEED_MAX --stat 10


sleep 3;
cat ./.run/wparse.pid  | xargs kill || true

sleep 3;
wproj  data stat
wproj  data validate --input-cnt $LINE_CNT
