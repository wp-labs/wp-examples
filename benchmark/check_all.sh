#!/usr/bin/env bash
set -euo pipefail

# Batch checker for all benchmark cases.
# Usage: ./check_all.sh [--stop-on-failure|-s]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Set COMMON_LIB to the correct path for benchmark root before sourcing benchmark_common.sh
export COMMON_LIB="$(cd "$SCRIPT_DIR/../script" && pwd)/common.sh"

# Source benchmark_common which internally sources common.sh
BENCH_COMMON="$SCRIPT_DIR/benchmark_common.sh"
if [ ! -f "$BENCH_COMMON" ]; then
  echo "Error: benchmark_common.sh not found at $BENCH_COMMON" >&2
  exit 2
fi
source "$BENCH_COMMON"

STOP_ON_FAIL=0
for arg in "$@"; do
  case "$arg" in
    --stop-on-failure|-s) STOP_ON_FAIL=1 ;;
    *) ;;
  esac
done

# Init env and build once
benchmark_init_env

# Discover all run.sh files at 3-level depth (case_*/subdir/run.sh)
# and 2-level depth (e.g., wpgen_test/run.sh)
CASES=()
while IFS= read -r -d '' f; do
  CASES+=("$f")
done < <(find . -type f -name run.sh -print0 | sort -z)

# Filter: skip known non-case directories
FILTERED=()
for c in "${CASES[@]}"; do
  dir="$(dirname "$c")"
  skip=0
  # Check each path component against skip-list
  IFS='/' read -ra COMPONENTS <<< "$dir"
  for comp in "${COMPONENTS[@]}"; do
    case "$comp" in
      sources|cases|topology) skip=1; break ;;
    esac
    # Skip directories matching *.md pattern (check_run.sh skips these)
    if [[ "$comp" == *.md ]]; then
      skip=1
      break
    fi
  done
  if [ "$skip" -eq 0 ]; then
    FILTERED+=("$c")
  fi
done

TOTAL=0
PASSED=0
FAILED=0
FAIL_LIST=()
TOTAL_CASES=${#FILTERED[@]}

start_ts=$(date +%s)
for run_sh in "${FILTERED[@]}"; do
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
