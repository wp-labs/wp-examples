#!/usr/bin/env bash
# 通用函数库，供各个 case_verify.sh 脚本调用

# 初始化脚本环境：设置 SCRIPT_DIR 并切换到该目录
init_script_dir() {
  # Always recalculate SCRIPT_DIR based on the calling script's location
  if [ -n "${BASH_SOURCE:-}" ] && [ ${#BASH_SOURCE[@]} -gt 1 ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  else
    SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
  fi
  cd "$SCRIPT_DIR"
  export SCRIPT_DIR
}

# 解析并验证 PROFILE 参数（debug|release）
parse_profile() {
  local default_profile="${1:-debug}"
  PROFILE=${PROFILE:-"$default_profile"}
  case "$PROFILE" in
    debug|release) ;;
    *) echo "invalid PROFILE: $PROFILE (expect debug|release)"; exit 2;;
  esac
  export PROFILE
}

# 解析并验证 RUN_MODE 参数（fg|bg）
parse_run_mode() {
  local default_mode="${1:-fg}"
  RUN_MODE=${RUN_MODE:-"$default_mode"}
  case "$RUN_MODE" in
    fg|bg) ;;
    *) echo "invalid RUN_MODE: $RUN_MODE (expect fg|bg)"; exit 2;;
  esac
  export RUN_MODE
}

# 清理运行输出目录，可选择是否保留 conf 目录
# 参数: $1 - 如果为 "keep_conf" 则保留 conf 目录
clean_runtime_dirs() {
  local keep_conf="${1:-}"
  if [ "$keep_conf" = "keep_conf" ]; then
    rm -rf tmp logs out rescue src_dat || true
  else
    rm -rf tmp conf logs out rescue src_dat || true
  fi
}

# 设置 PATH，优先检查 $HOME/bin 下的可执行文件
# 无参数，使用全局变量 PROFILE
build_and_setup_path() {
  # 如果 wparse 已经可以直接调用，则跳过 PATH 设置
  if command -v wparse >/dev/null 2>&1; then
    echo "wparse already available at $(command -v wparse)"
    return 0
  fi

  # 检查 $HOME/bin 目录是否存在且包含所需的可执行文件
  if [ -d "$HOME/bin" ]; then
    export PATH="$HOME/bin:$PATH"
    echo "Using executables from \$HOME/bin"
    return 0
  fi

  # Resolve repository root by walking up until we find a Cargo.toml along with 'usecase' dir
  local cur="$SCRIPT_DIR"
  while [ "$cur" != "/" ]; do
    if [ -f "$cur/Cargo.toml" ] && [ -d "$cur/usecase" ]; then
      REPO_ROOT="$cur"
      break
    fi
    cur="$(cd "$cur/.." && pwd)"
  done
  if [ -z "${REPO_ROOT:-}" ]; then
    echo "cannot resolve repo root from SCRIPT_DIR=$SCRIPT_DIR" >&2
    exit 2
  fi

  BIN_DIR="$REPO_ROOT/target/$PROFILE"

  # 如果外部已声明跳过构建（例如批量执行脚本统一编译），则只配置 PATH
  if [ "${SKIP_BUILD:-0}" = "1" ]; then
    export PATH="$BIN_DIR:$PATH"
    export REPO_ROOT BIN_DIR
    return 0
  fi

  # 默认优先构建 shim（apps-shim/*），避免启用 all-features 触发企业或 legacy 冲突。
  # 可通过 PREFER_SHIM=0 切回 legacy apps（将启用 root 的 legacy-apps 特性）。
  PREFER_SHIM=${PREFER_SHIM:-1}
  if [ "$PREFER_SHIM" = "1" ]; then
    if [ "$PROFILE" = "release" ]; then
      (cd "$REPO_ROOT" && cargo build-apps   --release) >/dev/null
    else
      (cd "$REPO_ROOT" && cargo build-apps ) >/dev/null
    fi
  else
    # 兼容回退：构建 legacy apps（最小特性，仅启用 legacy-apps）。
    if [ "$PROFILE" = "release" ]; then
      (cd "$REPO_ROOT" && cargo build --bins --release) >/dev/null
    else
      (cd "$REPO_ROOT" && cargo build  --bins) >/dev/null
    fi
  fi
  export PATH="$BIN_DIR:$PATH"
  export REPO_ROOT BIN_DIR
}

# 验证指定的命令是否存在于 PATH 中
# 参数: $@ - 要检查的命令列表
verify_commands() {
  for cmd in "$@"; do
    if command -v "$cmd" >/dev/null; then
      # 检查命令是否在 $HOME/bin 中
      cmd_path=$(command -v "$cmd")
      if [[ "$cmd_path" == "$HOME/bin/"* ]]; then
        echo "✓ Found $cmd at $cmd_path (from \$HOME/bin)"
      else
        echo "✓ Found $cmd at $cmd_path"
      fi
    else
      echo "✗ $cmd not found in PATH=$PATH"
      echo "  Please ensure $cmd is available in \$HOME/bin or PATH"
      exit 127
    fi
  done
}

# 后台运行模式的清理函数
bg_cleanup() {
  local pid_file="${1:-./.run/wparse.pid}"
  if [ -f "$pid_file" ]; then
    kill -TERM "$(cat "$pid_file")" 2>/dev/null || true
  fi
}

# 等待 PID 文件出现
# 参数: $1 - PID 文件路径，默认 ./.run/wparse.pid
wait_for_pid_file() {
  local pid_file="${1:-./.run/wparse.pid}"
  local max_attempts=50

  for _ in $(seq 1 "$max_attempts"); do
    test -f "$pid_file" && return 0
    sleep 0.1
  done

  echo "Warning: $pid_file did not appear after ${max_attempts} attempts"
  return 1
}
