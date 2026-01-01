#!/usr/bin/env bash
set -euo pipefail

# =========================
# 记录初始目录（关键）
# =========================
ORIG_DIR="$(pwd)"

# =========================
# 基础配置
# =========================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$BASE_DIR/parse-work"
LOG_DIR="$WORK_DIR/data/logs"

mkdir -p "$LOG_DIR"

# =========================
# 清理函数
# =========================
cleanup() {
    echo "[INFO] Cleaning up..."

    # 1. 杀掉当前进程组下的所有子进程
    kill -- -$$ 2>/dev/null || true

    # 2. 回到脚本启动前的目录
    cd "$ORIG_DIR" || true

    # 3. 关闭 docker compose
    docker compose down || true

    echo "[INFO] Cleanup completed."
}

# 捕获所有关键退出信号
trap cleanup EXIT INT TERM

# =========================
# 启动 docker
# =========================
docker compose up -d

# =========================
# 进入工作目录
# =========================
cd "$WORK_DIR"

# =========================
# 启动后台进程
# =========================
wparse daemon --stat 2 -p \
  > "$LOG_DIR/wparse-info.log" 2>&1 &

wpgen sample -c wpgen-kafka.toml --stat 2 -p \
  > "$LOG_DIR/wpgen-kafka.log" 2>&1 &

wpgen sample -c wpgen-tcp.toml --stat 2 -p \
  > "$LOG_DIR/wpgen-tcp.log" 2>&1 &

wpgen sample -c wpgen-file.toml --stat 2 -p \
  > "$LOG_DIR/wpgen-file.log" 2>&1 &

echo "[INFO] All processes started."

# =========================
# 阻塞主进程
# =========================
wait
