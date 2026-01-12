#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 验证必要的命令存在
for cmd in wproj wprescue; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

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

wproj data stat
wproj data validate
