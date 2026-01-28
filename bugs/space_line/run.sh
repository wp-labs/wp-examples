#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 加载 benchmark 公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_LIB="$(cd "$SCRIPT_DIR/../.." && pwd)/benchmark/benchmark_common.sh"
source "$BENCHMARK_LIB"
export COMMON_LIB="$(cd "$SCRIPT_DIR/../.." && pwd)/script/common.sh"

# 显示用法（包含 -f 选项）
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  benchmark_usage "$0" "-f"
  exit 0
fi

# 解析参数（支持 -m 和 -f）
benchmark_parse_args "$@"

# 初始化环境
benchmark_init_env

# 解析 WPL 路径（bugs 用例目录结构与 benchmark 不同）
if [[ -z "${WPL_DIR:-}" ]]; then
  WPL_DIR="apache"
fi
WPL_PATH="./models/wpl/${WPL_DIR}"
if [[ ! -d "$WPL_PATH" ]]; then
  echo "wpl dir not found: $WPL_PATH" >&2
  echo "available wpl dirs:" >&2
  ls -1 "./models/wpl" 2>/dev/null || echo "Cannot list ./models/wpl"
  exit 2
fi
echo "Using WPL path: $WPL_PATH"

# 初始化配置
wproj check
wproj data clean

# 设置数据规模
benchmark_set_line_cnt

# 检查数据文件（使用单个配置 "gen"）
benchmark_check_data_files "gen"

# 条件生成数据
benchmark_conditional_data_gen "$WPL_PATH" "$SPEED_MAX" "$LINE_CNT" 

# 检测生成数据中是否存在空行（复现 parallel=2 空行问题）
empty_lines=""
if [[ -f "./data/in_dat/gen.dat" ]]; then
  empty_lines=$(grep -n '^[[:space:]]*$' ./data/in_dat/gen.dat | wc -l | tr -d ' ')
  if [[ "$empty_lines" != "0" ]]; then
    echo "WARNING: found ${empty_lines} empty lines in ./data/in_dat/gen.dat"
  else
    echo "OK: no empty lines found in ./data/in_dat/gen.dat"
  fi
fi

# 执行 batch 模式测试
benchmark_run_batch "$WPL_PATH"

# 结尾再次输出空行统计，方便日志定位
if [[ -n "${empty_lines:-}" ]]; then
  if [[ "$empty_lines" != "0" ]]; then
    echo "SUMMARY: found ${empty_lines} empty lines in ./data/in_dat/gen.dat"
  else
    echo "SUMMARY: no empty lines found in ./data/in_dat/gen.dat"
  fi
fi
