#!/usr/bin/env bash
set -euo pipefail

# Batch checker for all subcases under this directory.
# Usage: ./check_all.sh [--stop-on-failure|-s]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMMON_LIB="${COMMON_LIB:-$(cd "$SCRIPT_DIR/../script" && pwd)/common.sh}"
if [ ! -f "$COMMON_LIB" ]; then
  COMMON_LIB="$SCRIPT_DIR/common.sh"
fi
source "$COMMON_LIB"

STOP_ON_FAIL=0
for arg in "$@"; do
  case "$arg" in
    --stop-on-failure|-s) STOP_ON_FAIL=1 ;;
    *) ;;
  esac
done

# Init env and build once
init_script_dir
build_and_setup_path
verify_commands wpadm || true

# Collect case directories (same discovery as run_all.sh)
CASES=()
CASES_STR="$(find . -maxdepth 2 -mindepth 1 -type f -name run.sh 2>/dev/null || true)"
if [ -z "$CASES_STR" ]; then
  CASES_STR="$(find . -type f -name run.sh)"
fi
while IFS= read -r line; do
  [ -n "$line" ] && CASES+=("$line")
done <<< "$(printf '%s\n' "$CASES_STR" | sort)"

ORDERED=()
for c in "${CASES[@]}"; do
  [[ "$c" == *"/getting_started/run.sh" ]] && ORDERED+=("$c")
done
for c in "${CASES[@]}"; do
  [[ "$c" == *"/getting_started/run.sh" ]] && continue
  ORDERED+=("$c")
done

TOTAL=0
PASSED=0
FAILED=0
FAIL_LIST=()
TOTAL_CASES=${#ORDERED[@]}

start_ts=$(date +%s)
for case_sh in "${ORDERED[@]}"; do
  TOTAL=$((TOTAL+1))
  case_dir="$(dirname "$case_sh")"
  case_name="${case_dir#./}"
  echo
  echo "====> [$TOTAL/$TOTAL_CASES] wpadm check: $case_name"

  set +e
  wpadm check --work-root "$case_dir" 2>&1
  rc=$?
  set -e

  if [ $rc -eq 0 ]; then
    PASSED=$((PASSED+1))
    echo "====> PASS: $case_name"
  else
    FAILED=$((FAILED+1))
    FAIL_LIST+=("$case_name (rc=$rc)")
    echo "====> FAIL: $case_name (rc=$rc)"
    if [ "$STOP_ON_FAIL" = "1" ]; then
      break
    fi
  fi
done

end_ts=$(date +%s)
echo
echo "Summary: total=$TOTAL, passed=$PASSED, failed=$FAILED, duration=$((end_ts-start_ts))s"
if [ "$FAILED" -ne 0 ]; then
  printf 'Failed cases:\n'
  for n in "${FAIL_LIST[@]}"; do echo " - $n"; done
  exit 1
fi
exit 0
