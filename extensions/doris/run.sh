#!/usr/bin/env bash
set -euo pipefail

# 1. 确认执行在当前目录
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "[1/2] 生成样例数据..."
wpgen sample -n 100 --stat 2 -p

echo "[2/2] 执行 wparse batch..."
wparse batch --stat 2 -S 1 -p
