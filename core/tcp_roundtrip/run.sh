#!/usr/bin/env bash
set -euo pipefail

# Enter script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Verify commands exist
for cmd in wparse wpgen wproj lsof; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Command '$cmd' not found in PATH"
    exit 1
  fi
done

wproj check
wproj data clean
wpgen data clean

# 预清理：释放默认 syslog TCP 端口（防止上次遗留进程占用 1514）
if command -v lsof >/dev/null 2>&1; then
  lsof -t -nP -iTCP:1514 2>/dev/null | xargs -r kill -9 || true
fi

echo "2> start work (no print_stat)"
wparse deamon --stat 2  -w 2 &
# Wait for PID file with simple loop
for i in {1..50}; do
  if test -f "./.run/wparse.pid"; then
    break
  fi
  sleep 0.1
done
sleep 3

LINE_CNT=50000
echo "1> gen sample data"
wpgen sample -n "$LINE_CNT"  --stat  1 -p


sleep 3
cat ./.run/wparse.pid | xargs kill || true

sleep 3
wproj data stat
wproj data validate --input-cnt "$LINE_CNT"
