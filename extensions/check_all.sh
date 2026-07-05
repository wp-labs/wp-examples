#!/usr/bin/env bash
set -euo pipefail

# Batch checker for all extension cases.
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

init_script_dir
build_and_setup_path
verify_commands wpadm || true

# Discover all run.sh files (2-level depth: extension_name/run.sh)
CASES=()
while IFS= read -r -d '' f; do
  CASES+=("$f")
done < <(find . -maxdepth 2 -mindepth 1 -type f -name run.sh -print0 | sort -z)

TOTAL=0
PASSED=0
FAILED=0
FAIL_LIST=()
TOTAL_CASES=${#CASES[@]}

start_ts=$(date +%s)
for run_sh in "${CASES[@]}"; do
  TOTAL=$((TOTAL+1))
  case_dir="$(dirname "$run_sh")"
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
