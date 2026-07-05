#!/usr/bin/env bash
set -euo pipefail

# Enter script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Verify commands exist
for cmd in wparse wpgen wpadm lsof; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Command '$cmd' not found in PATH"
    exit 1
  fi
done

wpadm check
wpadm data clean
wpgen data clean


echo "2> start work (no print_stat)"
wparse daemon --stat 2  -w 2 -p &
# Wait for PID file with simple loop
for i in {1..50}; do
  if test -f "./.run/wparse.pid"; then
    break
  fi
  sleep 0.1
done
# Wait for wparse to bind UDP ports (PID alone != ports ready)
for i in {1..30}; do
  if lsof -iUDP:1524 >/dev/null 2>&1 && lsof -iUDP:1525 >/dev/null 2>&1; then
    echo "wparse UDP ports ready"
    break
  fi
  sleep 0.5
done

LINE_CNT=10000
TOTAL_CNT=20000
echo "1> gen sample data"
wpgen sample -n "$LINE_CNT"  --stat  1 &
WP1=$!
wpgen sample -c wpgen2.toml -n "$LINE_CNT"  --stat  1 &
WP2=$!
wait $WP1 $WP2


sleep 3
kill -9 $(cat ./.run/wparse.pid) 2>/dev/null || true
# Wait until wparse is truly gone
for i in {1..20}; do
  if ! kill -0 $(cat ./.run/wparse.pid 2>/dev/null) 2>/dev/null; then
    echo "wparse stopped"
    break
  fi
  sleep 0.3
done
sleep 1
wpadm data stat
wpadm data validate --input-cnt "$TOTAL_CNT"
