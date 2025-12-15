#!/usr/bin/env bash
set -euo pipefail

# 加载公共函数库（统一到 usecase/script）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${COMMON_LIB:-$(cd "$SCRIPT_DIR/../../script" && pwd)/common.sh}"
if [ ! -f "$COMMON_LIB" ]; then
  COMMON_LIB="$(cd "$SCRIPT_DIR/.." && pwd)/common.sh"
fi
source "$COMMON_LIB"

usage() {
  cat <<'USAGE'
Usage: ./run.sh [-w worker_cnt] [profile]
  -w worker_cnt   与其它 benchmark 对齐的接口；当前脚本仅生成数据，会忽略该参数
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

if [ -n "$WORKER_ARG" ]; then
  echo "[INFO] -w 参数对当前脚本无效（仅生成数据），已忽略。" >&2
fi

wproj conf init
wproj data clean
wpgen data clean

LINE_CNT=8000000
SPEED_MAX=2000000
echo "gen $SPEED_MAX"
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat   2 -p  --wpl ./models/wpl/nginx


wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat   2 -p  --wpl ./models/wpl/benchmark




LINE_CNT=6000
SPEED_MAX=1000
echo "gen $SPEED_MAX"
wpgen sample -n $LINE_CNT -s $SPEED_MAX --stat   2 -p --wpl ./models/wpl/nginx
