#!/usr/bin/env bash
set -euo pipefail

# =========================
# 基础配置
# =========================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_DIR="$BASE_DIR/pids"

# =========================
# 停止后台进程
# =========================
echo "[INFO] Stopping background processes..."

MAX_RETRY=3      # 最大等待次数
SLEEP_INTERVAL=0.2

if [ -d "$PID_DIR" ]; then
    for pid_file in "$PID_DIR"/*.pid; do
        [ -f "$pid_file" ] || continue

        pid=$(cat "$pid_file")

        if kill -0 "$pid" 2>/dev/null; then
            echo "[INFO] Killing process $pid from $pid_file"
            kill "$pid" 2>/dev/null || true

            retry=0
            while kill -0 "$pid" 2>/dev/null; do
                if [ "$retry" -ge "$MAX_RETRY" ]; then
                    echo "[WARN] Process $pid still running after $MAX_RETRY retries, force killing..."
                    kill -9 "$pid" 2>/dev/null || true
                    break
                fi
                retry=$((retry + 1))
                sleep "$SLEEP_INTERVAL"
            done

            if kill -0 "$pid" 2>/dev/null; then
                echo "[ERROR] Failed to kill process $pid"
            else
                echo "[INFO] Process $pid stopped."
            fi
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
rm -rf $BASE_DIR/parse/data

echo "[INFO] All services stopped."
