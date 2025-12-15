#!/usr/bin/env bash
set -euo pipefail

# 该脚本由各 run.sh 通过 "source ../run_common.sh" 引入，
# 负责加载 usecase/script/common.sh 并封装公共的初始化流程。

# 记录调用 run_common.sh 的 run.sh 路径，便于定位 case 目录
__core_caller="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
CORE_CASE_DIR="$(cd "$(dirname "${__core_caller}")" && pwd)"
CORE_DIR="$(cd "$CORE_CASE_DIR/.." && pwd)"

# 加载统一的公共库实现
COMMON_LIB="${COMMON_LIB:-$(cd "$CORE_DIR/../script" && pwd)/common.sh}"
if [ ! -f "$COMMON_LIB" ]; then
  COMMON_LIB="$CORE_DIR/common.sh"
fi
# shellcheck disable=SC1090
source "$COMMON_LIB"

# 案例脚本常见的自举动作：
#   1. init_script_dir -> 进入案例目录
#   2. parse_profile   -> 解析 PROFILE
#   3. clean_runtime_dirs -> 可选清理运行目录
#   4. build_and_setup_path -> 构建并注入可执行路径
#   5. verify_commands -> 确认依赖的二进制存在
# 调用方式：core_usecase_bootstrap [profile=debug] [clean_mode=keep_conf] [commands...]
core_usecase_bootstrap() {
  local default_profile="debug"
  local clean_mode="keep_conf"
  local required_cmds=()

  if [ "$#" -gt 0 ]; then
    default_profile="$1"
    shift
  fi
  if [ "$#" -gt 0 ]; then
    clean_mode="$1"
    shift
  fi
  if [ "$#" -gt 0 ]; then
    required_cmds=("$@")
  fi

  init_script_dir
  # init_script_dir 会根据 BASH_SOURCE 推导路径，但在 run_common.sh
  # 链路下会定位到 core/ 目录。这里强制切换到具体用例目录。
  if [ "$SCRIPT_DIR" != "$CORE_CASE_DIR" ]; then
    cd "$CORE_CASE_DIR"
    SCRIPT_DIR="$CORE_CASE_DIR"
    export SCRIPT_DIR
  fi
  parse_profile "$default_profile"

  if [ -n "$clean_mode" ] && [ "$clean_mode" != "skip_clean" ]; then
    clean_runtime_dirs "$clean_mode"
  fi

  build_and_setup_path

  if [ "${#required_cmds[@]}" -gt 0 ]; then
    verify_commands "${required_cmds[@]}"
  fi
}
