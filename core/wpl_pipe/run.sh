#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# Tunables
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}

# 初始化环境（保留 conf 便于复用 wpl pipeline）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj

# Prepare conf and data
wproj check || true
wproj data clean || true
wpgen data clean || true

echo "1> gen sample data (base64+quoted JSON; quoted+escaped JSON)"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "2> parse in batch"
if ! wparse batch --stat "$STAT_SEC" -S 1 -p -n "$LINE_CNT"; then
  echo "wparse work failed. check ./data/logs/wparse.log and ./data/logs/wparse.stdout (if exists).";
  exit 1
fi

echo "3> validate outputs"
wproj data stat
wproj data validate
