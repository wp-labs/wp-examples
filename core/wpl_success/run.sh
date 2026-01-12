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

# Tunable parameters
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

echo "1> init wparse service"
# Force refresh configuration (only remove wparse.toml, regenerate via wproj) to avoid validation failures from old keys
wproj check || true

# Initialize configuration and data directories
wproj data clean || true
wpgen data clean || true

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"

echo "3> verify inputs"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "4> start wparse work"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
  echo "wparse work failed. check ./data/logs/wparse.log"
  exit 1
fi

echo "5> validate sinks by expect"
wproj data stat
wproj data validate
