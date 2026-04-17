#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

WORK_ROOT="$(pwd)"
LINE_CNT="${LINE_CNT:-1000}"
WPARSE_STAT_SEC="${WPARSE_STAT_SEC:-5}"

export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-5432}"
export PGDATABASE="${PGDATABASE:-wparse}"
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-123456}"

for cmd in python3 wproj wparse; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

if ! python3 -c "import psycopg" >/dev/null 2>&1; then
    echo "Error: 缺少 psycopg，请先执行：python3 -m pip install 'psycopg[binary]'"
    exit 1
fi

echo "1> 检查项目配置"
wproj check --work-root "$WORK_ROOT"

echo "2> 清理运行时数据"
wproj data clean --work-root "$WORK_ROOT"

echo "3> 创建源表和目标表"
python3 scripty/create_http_request_logs.py

echo "4> 写入测试数据"
python3 scripty/insert_http_request_logs_1000.py "$LINE_CNT"

echo "5> 清理旧 checkpoint"
python3 - <<'PY'
from pathlib import Path

checkpoint = Path(".run/.checkpoints/postgres_1.json")
if checkpoint.exists():
    checkpoint.unlink()
    print(f"已删除旧 checkpoint: {checkpoint}")
else:
    print(f"未发现旧 checkpoint: {checkpoint}")
PY

echo "6> 启动 wparse daemon"
exec wparse daemon --work-root "$WORK_ROOT" --stat "$WPARSE_STAT_SEC" -p
