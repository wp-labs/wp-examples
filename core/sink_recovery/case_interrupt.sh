#!/usr/bin/env bash
set -euo pipefail

# 加载公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${COMMON_LIB:-$(cd "$SCRIPT_DIR/../../script" && pwd)/common.sh}"
if [ ! -f "$COMMON_LIB" ]; then
  COMMON_LIB="$(cd "$SCRIPT_DIR/.." && pwd)/common.sh"
fi
source "$COMMON_LIB"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 初始化环境
init_script_dir
parse_profile "${1:-debug}"

echo "1> init wparse service"
# 清理运行输出但保留用例的 wpl/oml/source/sink 模板
clean_runtime_dirs  keep_conf # 删除 conf 目录

# 预构建，避免多次调用触发重复编译；并将 target/<profile> 加入 PATH 直接调用二进制
build_and_setup_path
verify_commands wparse wpgen wproj

wproj check
wproj init --mode data
wproj data clean
wpgen data clean
echo "1> gen sample data"
wpgen sample -n 10000 -s 10000  --stat 100
echo "2> start wparse work"
wparse batch --stat 10 --print_stat

echo "rescue data:"
find ./data/rescue/ -name "*.dat"
wproj  data stat
wproj  data validate
