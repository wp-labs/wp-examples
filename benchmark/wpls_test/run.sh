#!/usr/bin/env bash
set -euo pipefail

# 加载公共函数库（统一到 usecase/script）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
COMMON_LIB="${COMMON_LIB:-$(cd "$SCRIPT_DIR/../../script" && pwd)/common.sh}"
if [ ! -f "$COMMON_LIB" ]; then
  COMMON_LIB="$(cd "$SCRIPT_DIR/.." && pwd)/common.sh"
fi
source "$COMMON_LIB"

usage() {
  cat <<'USAGE'
Usage: ./run.sh [-w worker_cnt] [profile]
  -w worker_cnt   指定 wparse worker 数；默认依次运行 2/4/6
  profile         可选，默认 release
USAGE
}

WORKER_ARG=""
while getopts ":w:h" opt; do
  case "$opt" in
    w) WORKER_ARG="$OPTARG" ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done
shift $((OPTIND-1))

# 初始化与构建：基准测试默认使用 release
init_script_dir
parse_profile "${1:-release}"
build_and_setup_path
verify_commands wparse wpgen wproj

rm -rf  data/logs

#rm -rf  ./ldm ;
#wpcfg ldm  benchmark ;
#wpcfg ldm benchmark --sink null

STAT_SEC=20

wproj check
wproj data clean
wpgen data clean

echo "1> gen  1KM sample data"
wpgen sample -n 5000000  -s 300000 --stat 10 --print_stat

if [ -n "$WORKER_ARG" ]; then
  WORKER_LIST=("$WORKER_ARG")
else
  WORKER_LIST=(2 4 6)
fi

for idx in "${!WORKER_LIST[@]}"; do
  cnt="${WORKER_LIST[$idx]}"
  echo "2> start ${cnt} thread work "
  wparse batch --stat "$STAT_SEC" -w "$cnt" --print_stat
  if [ "$idx" -lt $((${#WORKER_LIST[@]} - 1)) ]; then
    wproj data clean
  fi
done
