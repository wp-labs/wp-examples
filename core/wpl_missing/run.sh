#!/usr/bin/env bash
set -euo pipefail

# Enter script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Verify commands exist
for cmd in wparse wpgen wpadm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Command '$cmd' not found in PATH"
    exit 1
  fi
done

# Tunable parameters
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}

echo "1> init wparse service"

# Initialize configuration and data directories
wpadm check
wpadm data clean || true
wpgen data clean || true
# Legacy wpcfg has been merged into wpadm model; no model building needed here

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT"

echo "3> configure and start wparse work"
# Legacy wpcfg has been merged into wpadm model; no model building needed here

wparse batch --stat "$STAT_SEC" -p

wpadm data stat
wpadm data validate
