#!/usr/bin/env bash
# Deprecated shim: forward to the unified library under usecase/script/common.sh
# 说明：避免在 usecase/core 与 usecase/script 维护两份实现造成行为漂移。
# 此文件仅做转发，今后如需修改公共函数，请修改 usecase/script/common.sh。

COMMON_LIB_SHIM="$(cd "$(dirname "${BASH_SOURCE[0]}")/../script" && pwd)/common.sh"
if [ -f "$COMMON_LIB_SHIM" ]; then
  # shellcheck disable=SC1090
  source "$COMMON_LIB_SHIM"
else
  echo "common shim missing: $COMMON_LIB_SHIM" >&2
  exit 1
fi
