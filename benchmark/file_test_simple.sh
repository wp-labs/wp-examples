#!/usr/bin/env bash
set -euo pipefail

echo "Testing simplified version..."

# 简化的参数解析
MEDIUM_MODE=0
FORCE_REGEN=0
WPL_DIR="nginx"
SPEED_MAX="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m)
      MEDIUM_MODE=1
      shift
      ;;
    -f)
      FORCE_REGEN=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [-f] [-m] [wpl_dir] [speed]"
      echo "  -f      : 强制重新生成数据，即使数据已存在"
      echo "  -m      : 使用中等规模数据集 (LINE_CNT=200000)"
      echo "  wpl_dir : nginx | sysmon | <other-dir> (default: nginx)"
      echo "  speed   : 生成限速（每秒行数），0 表示不限速（default: 0)"
      exit 0
      ;;
    *)
      if [ -z "$WPL_DIR" ] || [ "$WPL_DIR" = "nginx" ]; then
        WPL_DIR="$1"
      else
        SPEED_MAX="$1"
      fi
      shift
      ;;
  esac
done

echo "Configuration:"
echo "  MEDIUM_MODE: $MEDIUM_MODE"
echo "  FORCE_REGEN: $FORCE_REGEN"
echo "  WPL_DIR: $WPL_DIR"
echo "  SPEED_MAX: $SPEED_MAX"

# 加载 common.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${COMMON_LIB:-$(cd "$SCRIPT_DIR/../../script" && pwd)/common.sh}"
echo "Loading: $COMMON_LIB"

if [ ! -f "$COMMON_LIB" ]; then
  echo "Error: Cannot find common.sh at: $COMMON_LIB" >&2
  exit 2
fi

source "$COMMON_LIB"

echo "Successfully loaded common.sh"

# 设置数据规模
if [ "$MEDIUM_MODE" = "1" ]; then
  LINE_CNT=200000
  echo "Using medium dataset: LINE_CNT=$LINE_CNT"
else
  LINE_CNT=20000000
  echo "Using large dataset: LINE_CNT=$LINE_CNT"
fi