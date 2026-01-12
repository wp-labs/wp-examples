#!/usr/bin/env bash
set -euo pipefail

# 加载 benchmark 公共函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_LIB="$(cd "$SCRIPT_DIR/../.." && pwd)/benchmark_common.sh"
source "$BENCHMARK_LIB"

# 显示用法（不包含 -f 选项）
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  benchmark_usage "$0" ""
  exit 0
fi

# 解析参数（只支持 -m）
benchmark_parse_args "$@"

# 初始化环境
benchmark_init_env

# 验证 WPL 路径
benchmark_validate_wpl_path "$WPL_DIR"

# 初始化配置
wproj check

wproj data clean
wpgen data clean

# 设置数据规模
benchmark_set_line_cnt

# 执行 daemon 模式测试（运行 30 秒）
#benchmark_run_daemon "$WPL_PATH" "$SPEED_MAX" "$LINE_CNT" "wpgen.toml"  "wpgen2.toml"
benchmark_run_daemon "$WPL_PATH" "$SPEED_MAX" "$LINE_CNT" "wpgen.toml"
