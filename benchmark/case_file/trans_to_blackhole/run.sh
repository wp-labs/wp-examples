#!/usr/bin/env bash
set -euo pipefail

# 加载 benchmark 公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_LIB="$(cd "$SCRIPT_DIR/../.." && pwd)/benchmark_common.sh"
source "$BENCHMARK_LIB"

# 显示用法（包含 -f 选项）
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  benchmark_usage "$0" "-f"
  exit 0
fi

# 解析参数（支持 -m 和 -f）
benchmark_parse_args "$@"

# 初始化环境
benchmark_init_env

# 验证 WPL 路径
benchmark_validate_wpl_path "$WPL_DIR"

# 初始化配置
wproj check
#wproj data clean

# 设置数据规模
benchmark_set_line_cnt

# 检查数据文件（使用单个配置 "gen"）
benchmark_check_data_files "gen"

# 条件生成数据

benchmark_conditional_data_gen "$WPL_PATH" "$SPEED_MAX" "$LINE_CNT" "wpgen.toml"

# 执行 batch 模式测试
benchmark_run_batch "$WPL_PATH"
