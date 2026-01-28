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


echo "2> start work (no print_stat)"
wparse deamon --stat 2  -w 2 -p &
# Wait for PID file with simple loop
for i in {1..50}; do
  if test -f "./.run/wparse.pid"; then
    break
  fi
  sleep 0.1
done
sleep 3

LINE_CNT=10000
TOTAL_CNT=20000
echo "1> gen sample data"
wpgen sample -n "$LINE_CNT"  --stat  1 &
wpgen sample -c wpgen2.toml -n "$LINE_CNT"  --stat  1


sleep 3
cat ./.run/wparse.pid | xargs kill || true

sleep 3
wproj data stat
wproj data validate --input-cnt "$TOTAL_CNT"
