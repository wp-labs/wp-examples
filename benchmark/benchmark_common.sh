#!/usr/bin/env bash
# benchmark 公共函数库，供各个 benchmark 脚本使用

# 显示用法信息
# 参数: $1 - 脚本名称
#       $2 - 脚本特定选项（可选）
benchmark_usage() {
  local script_name="$1"
  local extra_options="${2:-}"

  echo "Usage: $script_name [-m] [-f] [-c line_cnt] [-w worker_cnt] [wpl_dir] [speed]"
  echo "  -m      : 使用中等规模数据集 (LINE_CNT=200000)"
  if [[ "$extra_options" == *"-f"* ]]; then
    echo "  -f      : 强制重新生成数据，即使数据已存在"
  fi
  echo "  -c cnt  : 指定数据条数 (与 -m 互斥，优先级更高)"
  echo "  -w cnt  : 指定 wparse worker 数（daemon 默认 6，batch/blackhole 默认 10）"
  echo "  wpl_dir : nginx | sysmon | <other-dir> (default: nginx)"
  echo "  speed   : 生成限速（每秒行数），0 表示不限速（default: 0)"
}

# 解析通用参数
# 支持的参数: -m, -f, wpl_dir, speed
# 设置全局变量: MEDIUM_MODE, FORCE_REGEN, WPL_DIR, SPEED_MAX, ARGS
benchmark_parse_args() {
  MEDIUM_MODE=0
  FORCE_REGEN=0
  WPL_DIR=""
  SPEED_MAX="0"
  WORKER_CNT=""
  CUSTOM_LINE_CNT=""
  ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m)
        MEDIUM_MODE=1
        shift
        ;;
      -c)
        if [[ -z "${2:-}" ]]; then
          echo "-c requires a line count" >&2
          exit 2
        fi
        if ! [[ "$2" =~ ^[0-9]+$ ]]; then
          echo "-c expects an integer line count" >&2
          exit 2
        fi
        CUSTOM_LINE_CNT="$2"
        shift 2
        ;;
      -f)
        FORCE_REGEN=1
        shift
        ;;
      -w)
        if [[ -z "${2:-}" ]]; then
          echo "-w requires a worker count" >&2
          exit 2
        fi
        WORKER_CNT="$2"
        shift 2
        ;;
      -h|--help)
        benchmark_usage "$0" "$1"
        exit 0
        ;;
      *)
        ARGS+=("$1")
        shift
        ;;
    esac
  done

  # 解析位置参数：wpl_dir 和 speed
  if [[ ${#ARGS[@]} -ge 2 ]]; then
    WPL_DIR="${ARGS[0]}"
    SPEED_MAX="${ARGS[1]}"
  elif [[ ${#ARGS[@]} -eq 1 ]]; then
    WPL_DIR="${ARGS[0]}"
    SPEED_MAX="0"
  fi
}

# 初始化基准测试环境
# 固定使用 release profile
benchmark_init_env() {
  # 加载公共函数库 - 直接使用已知的正确路径
  local common_lib="${COMMON_LIB:-$(cd "$(dirname "${BASH_SOURCE[1]}")/../../../script" && pwd)/common.sh}"
  if [ ! -f "$common_lib" ]; then
    echo "Error: Cannot find common.sh library at: $common_lib" >&2
    exit 2
  fi

  source "$common_lib"

  # 保存当前工作目录
  local original_pwd="$(pwd)"

  # 初始化与构建（这可能会改变工作目录）
  parse_profile "release"
  build_and_setup_path
  verify_commands wparse wpgen wproj

  # 恢复原始工作目录
  cd "$original_pwd"
}

# 设置 LINE_CNT 并显示信息
# 设置全局变量: LINE_CNT
benchmark_set_line_cnt() {
  if [ -n "${CUSTOM_LINE_CNT:-}" ]; then
    LINE_CNT="$CUSTOM_LINE_CNT"
    echo "Using custom dataset: LINE_CNT=$LINE_CNT"
  elif [ "$MEDIUM_MODE" = "1" ]; then
    LINE_CNT=200000
    echo "Using medium dataset: LINE_CNT=$LINE_CNT"
  else
    LINE_CNT=20000000
    echo "Using large dataset: LINE_CNT=$LINE_CNT"
  fi
}

# 验证 WPL 目录
# 参数: $1 - WPL 目录名称
# 返回: WPL_PATH 全局变量
benchmark_validate_wpl_path() {
  local wpl_dir="${1:-$WPL_DIR}"

  # 获取脚本所在的原始目录
  local script_dir
  if [ -n "${BASH_SOURCE:-}" ] && [ ${#BASH_SOURCE[@]} -gt 1 ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  else
    script_dir="$(cd "$(dirname "${0}")" && pwd)"
  fi

  # 特殊处理：mix 使用 wpl 根目录
  if [ "$wpl_dir" = "mix" ]; then
    wpl_dir=""
  fi

  # 始终基于脚本所在目录计算相对路径
  # 从 benchmark 子目录到 models/wpl
  WPL_PATH="../../models/wpl/${wpl_dir}"

  if [ ! -d "$WPL_PATH" ]; then
    echo "wpl dir not found: $WPL_PATH" >&2
    echo "available wpl dirs:" >&2
    ls -1 "$(dirname "$WPL_PATH")" 2>/dev/null || echo "Cannot list $(dirname "$WPL_PATH")"
    exit 2
  fi

  echo "Using WPL path: $WPL_PATH"
}

# 检查数据文件是否存在
# 参数: $1 - 配置文件名称数组 (可选，默认为 "gen")
# 设置全局变量: DATA_FILES_EXIST
benchmark_check_data_files() {
  local config_files=("$@")
  if [ ${#config_files[@]} -eq 0 ]; then
    config_files=("gen")
  fi

  DATA_FILES_EXIST=false

  echo "Checking existing data files..."
  for config in "${config_files[@]}"; do
    local data_file="./data/in_dat/${config}.dat"
    if [ -f "$data_file" ] && [ -s "$data_file" ]; then
      echo "Found existing data file: $data_file ($(wc -l < "$data_file") lines)"
      DATA_FILES_EXIST=true
    else
      echo "Missing data file: $data_file"
      DATA_FILES_EXIST=false
      break
    fi
  done
}

# 条件生成数据
# 参数: $1 - WPL 路径
#       $2 - 速度限制
#       $3 - LINE_CNT
#       $4 - 配置文件数组 (可选，默认为 "wpgen.toml")
#       $@ - 额外的 wpgen 参数 (可选)
benchmark_conditional_data_gen() {
  local wpl_path="$1"
  local speed="$2"
  local line_cnt="$3"
  shift 3
  local config_files=("$@")

  # 如果没有提供配置文件，使用默认的 wpgen.toml
  if [ ${#config_files[@]} -eq 0 ]; then
    config_files=("wpgen.toml")
  fi

  # 如果数据文件存在且不强制重新生成，则跳过
  if [ "$DATA_FILES_EXIST" = true ] && [ "$FORCE_REGEN" = 0 ]; then
    echo "Data files already exist and -f flag not specified. Skipping data generation."
    return 0
  fi

  # 清理数据（根据需要）
  if [ "$FORCE_REGEN" = 1 ]; then
    echo "Force regeneration (-f flag specified). Regenerating data..."
    for config in "${config_files[@]}"; do
      wpgen data clean -c "$config" 2>/dev/null || true
    done
  else
    echo "Data files missing. Generating new data..."
  fi

  echo "1> Generating sample data (wpl=$wpl_path, speed=$speed)"
  for config in "${config_files[@]}"; do
    wpgen sample -c "$config" -n "$line_cnt" -s "$speed" --stat 2 --wpl "$wpl_path"
  done
}

# 执行 batch 模式的基准测试
# 参数: $1 - WPL 路径
#       $@ - 额外的 wparse 参数 (可选)
benchmark_run_batch() {
  local wpl_path="$1"
  shift
  local work_cnt="${WORKER_CNT:-10}"

  echo "2> Running batch processing"
  if [ $# -gt 0 ]; then
    wparse batch --wpl "$wpl_path" --stat 1 -w "$work_cnt" -p "$@"
  else
    wparse batch --wpl "$wpl_path" --stat 1 -w "$work_cnt" -p
  fi

  sleep 1
  wproj data stat
}

# 执行 daemon 模式的基准测试
# 参数: $1 - WPL 路径
#       $2 - 速度限制
#       $3 - LINE_CNT
#       $4 - 第一个 wpgen 配置文件 (可选，默认为 "wpgen.toml")
#       $5 - 第二个 wpgen 配置文件 (可选，用于双源场景)
#       $@ - 额外的 wparse 参数 (可选，位于配置参数之后)
benchmark_run_daemon() {
  local wpl_path="$1"
  local speed="$2"
  local line_cnt="$3"
  shift 3
  local config1="wpgen.toml"
  local config2=""

  if [ $# -gt 0 ]; then
    config1="$1"
    shift
  fi
  if [ $# -gt 0 ]; then
    config2="$1"
    shift
  fi

  local work_cnt="${WORKER_CNT:-6}"

  echo "2> Starting daemon mode (no print_stat)"
  if [ $# -gt 0 ]; then
    wparse deamon --wpl "$wpl_path" --stat 1 -w "$work_cnt" -p "$@" & \
      wait_for_pid_file ./.run/wparse.pid || true
  else
    wparse deamon --wpl "$wpl_path" --stat 1 -w "$work_cnt" -p & \
      wait_for_pid_file ./.run/wparse.pid || true
  fi
  sleep 1

  echo "1> Generating sample data (wpl=$wpl_path, speed=$speed)"
  if [ -n "$config2" ]; then
    echo "1> Generating sample data via second config (config=$config2)"
    wpgen sample -n "$line_cnt" -s "$speed" --stat 10 --wpl "$wpl_path" -c "$config2" &
  fi

  wpgen sample -n "$line_cnt" -s "$speed" --stat 10 --wpl "$wpl_path" -c "$config1"

  sleep 1
  cat ./.run/wparse.pid | xargs kill || true

  sleep 1
  wproj  data stat
}

# 执行 blackhole 模式的基准测试（类似 daemon，但不生成数据）
# 参数: $1 - WPL 路径
#       $2 - 运行时间（秒）
#       $@ - 额外的 wparse 参数 (可选)
benchmark_run_blackhole() {
  local wpl_path="$1"
  local duration="${2:-30}"
  shift 2
  local work_cnt="${WORKER_CNT:-10}"

  echo "2> Starting blackhole mode (duration: ${duration}s)"
  if [ $# -gt 0 ]; then
    wparse deamon --wpl "$wpl_path" --stat 1 -w "$work_cnt" -p "$@" & \
      wait_for_pid_file ./.run/wparse.pid || true
  else
    wparse deamon --wpl "$wpl_path" --stat 1 -w "$work_cnt" -p & \
      wait_for_pid_file ./.run/wparse.pid || true
  fi
  sleep 2

  echo "Running for $duration seconds..."
  sleep "$duration"

  echo "Stopping daemon..."
  cat ./.run/wparse.pid | xargs kill || true

  sleep 2
  wproj  data stat
}

# 显示配置信息
benchmark_show_config() {
  echo "Benchmark Configuration:"
  echo "  WPL_DIR: $WPL_DIR"
  echo "  WPL_PATH: ${WPL_PATH:-未设置}"
  echo "  SPEED_MAX: $SPEED_MAX"
  echo "  MEDIUM_MODE: $MEDIUM_MODE"
  echo "  FORCE_REGEN: $FORCE_REGEN"
  echo "  LINE_CNT: ${LINE_CNT:-未设置}"
}
