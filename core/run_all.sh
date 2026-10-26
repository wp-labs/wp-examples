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
verify_commands wparse wpgen wpadm || true

# Ensure subcases reuse the compiled binaries (no rebuild)
export SKIP_BUILD=1

# Discover all case scripts.
# 递归收集 */*/run.sh（用例可以再嵌套一层，例如 stat_test/default_test），
# 但若某个祖级目录自身也有 run.sh，说明它统一驱动子用例，跳过子目录避免重复执行。
# 这里不用 mapfile/readarray，兼容 macOS 自带的 bash 3.2。
CASES=()
while IFS= read -r case_sh; do
  [ -n "$case_sh" ] || continue
  case_dir_only="$(dirname "$case_sh")"
  case_skip=0
  case_parent="$(dirname "$case_dir_only")"
  while [ "$case_parent" != "." ] && [ "$case_parent" != "/" ]; do
    if [ -f "$case_parent/run.sh" ]; then
      case_skip=1
      break
    fi
    case_parent="$(dirname "$case_parent")"
  done
  [ "$case_skip" -eq 1 ] && continue
  CASES+=("$case_sh")
done <<< "$(find . -mindepth 2 -type f -name run.sh | sort)"

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
