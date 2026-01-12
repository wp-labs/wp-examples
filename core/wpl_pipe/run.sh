#!/usr/bin/env bash
set -euo pipefail

# Enter script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Verify commands exist
for cmd in wparse wpgen wproj; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Command '$cmd' not found in PATH"
    exit 1
  fi
done

# Tunables
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}

# Prepare configuration and data
wproj check || true
wproj data clean || true
wpgen data clean || true

echo "1> gen sample data (base64+quoted JSON; quoted+escaped JSON)"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "2> parse in batch"
if ! wparse batch --stat "$STAT_SEC" -S 1 -p -n "$LINE_CNT"; then
  echo "wparse work failed. check ./data/logs/wparse.log and ./data/logs/wparse.stdout (if exists)."
  exit 1
fi

echo "3> validate outputs"
wproj data stat
wproj data validate
