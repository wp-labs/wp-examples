#!/usr/bin/env bash
set -euo pipefail

# Batch runner for all subcases under this directory.
# Usage: ./test_all.sh [debug|release] [--stop-on-failure]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Pre-build once at the beginning, then skip builds in each case
# Prefer unified usecase/script/common.sh; fallback to local shim for compatibility
COMMON_LIB="${COMMON_LIB:-$(cd "$SCRIPT_DIR/../script" && pwd)/common.sh}"
if [ ! -f "$COMMON_LIB" ]; then
  COMMON_LIB="$SCRIPT_DIR/common.sh"
fi
source "$COMMON_LIB"

PROFILE_ARG="${1:-}"; shift || true
STOP_ON_FAIL=0
for arg in "$@"; do
  case "$arg" in
    --stop-on-failure|-s) STOP_ON_FAIL=1 ;;
    *) ;; # ignore
  esac
done


# Init env and build once
init_script_dir
build_and_setup_path
verify_commands wparse wpgen wproj || true

# Ensure subcases reuse the compiled binaries (no rebuild)
export SKIP_BUILD=1

# Discover all case scripts
# Collect case scripts (compatible with older macOS bash without mapfile)
CASES=()
# Prefer shallow search; if not supported (BSD find), fall back to full search
CASES_STR="$(find . -maxdepth 2 -mindepth 1 -type f -name run.sh 2>/dev/null || true)"
if [ -z "$CASES_STR" ]; then
  CASES_STR="$(find . -type f -name run.sh)"
fi
while IFS= read -r line; do
  [ -n "$line" ] && CASES+=("$line")
done <<< "$(printf '%s\n' "$CASES_STR" | sort)"

# Move getting_started (if exists) to the front to seed initial artifacts
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
  echo "====> [$TOTAL/$TOTAL_CASES] 开始执行: $case_name"
  echo "      用例目录: $case_dir"

  # Run case and capture exit code (treat non-zero as failure)
  set +e
  (
    set -e
    cd "$case_dir"
    if [ -x "./run.sh" ]; then
      ./run.sh
    else
      bash ./run.sh
    fi
  )
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
