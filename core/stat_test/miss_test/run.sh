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

# 等管道排空：解析/落盘比生成慢，固定 sleep 会在积压未处理完时 kill 掉进程，
# 导致每次抓到的记录数在 60%~100% 之间抖动。
wait_drained() {
  local prev=-1 total=0 cur=0 stable=0 f
  for _ in $(seq 1 60); do
    total=0
    for f in "$@"; do
      [ -f "$f" ] || continue
      cur=$(wc -l < "$f" | tr -d ' ')
      total=$((total + cur))
    done
    if [ "$total" -eq "$prev" ]; then
      stable=$((stable + 1))
      if [ "$stable" -ge 2 ]; then
        echo "[drain] output stable at ${total} lines"
        return 0
      fi
    else
      stable=0
    fi
    prev=$total
    sleep 0.5
  done
  echo "[drain] timeout after 30s, last total=${prev}" >&2
  return 0
}

wpadm check
wpadm data clean
wpgen data clean

# 预清理：释放用例占用的 TCP 端口（防止上次遗留进程占用）
if command -v lsof >/dev/null 2>&1; then
  PIDS=$(lsof -t -nP -iTCP:19000 2>/dev/null || true)
  if [ -n "${PIDS:-}" ]; then
    kill -9 $PIDS 2>/dev/null || true
  fi
fi

echo "2> start work (no print_stat)"
wparse deamon --stat 5 -w 8 &
# Wait for PID file with simple loop
for i in {1..50}; do
  if test -f "./.run/wparse.pid"; then
    break
  fi
  sleep 0.1
done
sleep 3

LINE_CNT=10000
SPEED_MAX=5000
echo "1> gen sample data"
wpgen sample -n "$LINE_CNT" -s "$SPEED_MAX" --stat 10


sleep 1
wait_drained ./data/out_dat/miss.dat

cat ./.run/wparse.pid | xargs kill || true

sleep 3
wpadm data stat

# miss 数据是多行诊断块（6 行/条），行数比值不够直观，这里直接按记录数校验
MISS_RECORDS=$(grep -c '^src_key:' ./data/out_dat/miss.dat 2>/dev/null || true)
echo "check: miss records = ${MISS_RECORDS} / ${LINE_CNT} (expected >= 90%)"
[ "${MISS_RECORDS:-0}" -ge $(( LINE_CNT * 9 / 10 )) ] \
    || { echo "FAIL: expected ~${LINE_CNT} miss records, got ${MISS_RECORDS}" >&2; exit 1; }
wpadm data validate --input-cnt "$LINE_CNT"
