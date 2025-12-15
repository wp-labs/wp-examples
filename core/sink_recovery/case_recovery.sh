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
#clean_runtime_dirs  keep_conf # 删除 conf 目录

# 预构建，避免多次调用触发重复编译；并将 target/<profile> 加入 PATH 直接调用二进制
build_and_setup_path
verify_commands wproj  wprescue

# 若存在救急文件，则启动 wprescue 进行恢复；最多尝试 5 次
MAX_RUNS=5
RUN_CNT=0
RESCUE_DIR="./data/rescue"

echo "scan rescue dir: ${RESCUE_DIR}"
while [ "$RUN_CNT" -lt "$MAX_RUNS" ]; do
  if find "$RESCUE_DIR" -type f -name "*.dat" | grep -q . ; then
    echo "[recovery] run $((RUN_CNT+1))..."
    # 前台运行，利用恢复器的空闲退出（默认 3s 无新文件自动退出）
    if ! wprescue batch --stat 100; then
      echo "[recovery] wprescue exited with non-zero status (ignored for loop)"
    fi
    RUN_CNT=$((RUN_CNT+1))
  else
    echo "[recovery] no rescue .dat, stop loop"
    break
  fi
done
echo "[recovery] finished runs=$RUN_CNT (max=$MAX_RUNS)"

echo "rescue data:"
find ./data/rescue/ -name "*.dat"
wproj  data stat
wproj  data validate
