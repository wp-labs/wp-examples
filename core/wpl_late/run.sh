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

# Tunables
LINE_CNT=${LINE_CNT:-2000}
STAT_SEC=${STAT_SEC:-2}

# Prepare configuration and data
wpadm check || true
wpadm data clean || true
wpgen data clean || true
rm -rf .run

echo "1> gen sample data (5-line rotation: 3 structured + 2 free-form)"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "2> parse in batch"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
  echo "wparse work failed. check ./data/logs/wparse.log and ./data/logs/wparse.stdout (if exists)."
  exit 1
fi

echo "3> validate outputs"
wpadm data stat
wpadm data validate

echo
echo "pass: #[late] 兜底规则声明在最前面，仍然只拿到最后 40% 的自由文本。"
echo "      对照实验（去掉 #[late]，兜底规则会吃掉 100%）：./compare_naive.sh"
