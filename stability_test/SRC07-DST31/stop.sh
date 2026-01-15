BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

kill_by_name() {
    local name="$1"

    if [ -z "$name" ]; then
        echo "[ERROR] 请提供进程名称"
        return 1
    fi
    echo "[INFO] 查找进程: $name"
    pids=$(ps -ef | grep "$name" | grep -v grep | awk '{print $2}')
    if [ -z "$pids" ]; then
        echo "[INFO] 未找到相关进程"
        return 0
    fi
    echo "[INFO] 发现进程ID: $pids"
    for pid in $pids; do
        echo "[INFO] 正在终止进程: $pid"
        kill -9 "$pid"
    done
    echo "[INFO] 完成"
}
kill_by_name wparse
sleep 1

kill_by_name wpgen

rm -rf $BASE_DIR/parse/data