#!/usr/bin/env bash
set -euo pipefail

# =========================
# 基础配置
# =========================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$BASE_DIR/parse-work"
PID_DIR="$WORK_DIR/data/pids"

# =========================
# 停止后台进程
# =========================
echo "[INFO] Stopping background processes..."

if [ -d "$PID_DIR" ]; then
    for pid_file in "$PID_DIR"/*.pid; do
        [ -f "$pid_file" ] || continue
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "[INFO] Killing process $pid from $pid_file"
            kill "$pid" 2>/dev/null || true
            # 等待进程退出
            while kill -0 "$pid" 2>/dev/null; do
                sleep 0.2
            done
            echo "[INFO] Process $pid stopped."
        else
            echo "[INFO] Process $pid already not running."
        fi
        rm -f "$pid_file"
    done
else
    echo "[WARN] PID directory $PID_DIR does not exist."
fi

# =========================
# 停止 docker compose
# =========================
# echo "[INFO] Stopping Docker Compose..."
# docker compose down || true

echo "[INFO] All services stopped."
