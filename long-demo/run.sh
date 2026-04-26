#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# long-demo 一键启动脚本
# 数据流：wpgen (波动生成) → TCP → wparse (syslog_tcp_src) → monitor sink
# ============================================================================

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
WPARSE_BIN="${WPARSE_BIN:-wparse}"
WPGEN_BIN="${WPGEN_BIN:-wpgen}"
TCP_PORT=1514

cd "$DEMO_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    echo ""
    echo -e "${YELLOW}>>> 正在停止所有进程...${NC}"
    if [ -n "${WPARSE_PID:-}" ] && kill -0 "$WPARSE_PID" 2>/dev/null; then
        kill "$WPARSE_PID" 2>/dev/null || true
        wait "$WPARSE_PID" 2>/dev/null || true
    fi
    if [ -n "${WPGEN_PID:-}" ] && kill -0 "$WPGEN_PID" 2>/dev/null; then
        kill "$WPGEN_PID" 2>/dev/null || true
        wait "$WPGEN_PID" 2>/dev/null || true
    fi
    echo -e "${GREEN}>>> 已停止${NC}"
}
trap cleanup EXIT INT TERM

# ---- 检查二进制 ----
if ! command -v "$WPARSE_BIN" &>/dev/null; then
    echo -e "${RED}错误: 找不到 wparse 二进制 (WPARSE_BIN=$WPARSE_BIN)${NC}"
    echo "提示: 设置环境变量 WPARSE_BIN 或确保 wparse 在 PATH 中"
    exit 1
fi
if ! command -v "$WPGEN_BIN" &>/dev/null; then
    echo -e "${RED}错误: 找不到 wpgen 二进制 (WPGEN_BIN=$WPGEN_BIN)${NC}"
    echo "提示: 设置环境变量 WPGEN_BIN 或确保 wpgen 在 PATH 中"
    exit 1
fi

# ---- 准备数据目录 ----
mkdir -p "$DEMO_DIR/data/logs" "$DEMO_DIR/data/out_dat" "$DEMO_DIR/data/in_dat" "$DEMO_DIR/data/rescue"

# ---- 1. 启动 wparse (daemon 模式，监听 TCP 1514) ----
echo -e "${GREEN}>>> [1/3] 启动 wparse daemon (TCP :$TCP_PORT)...${NC}"
"$WPARSE_BIN" daemon --work-root "$DEMO_DIR"  --stat 1 -p  &
WPARSE_PID=$!

# ---- 2. 等待 wparse 就绪 ----
echo -e "${YELLOW}>>> [2/3] 等待 wparse 就绪...${NC}"
for i in $(seq 1 30); do
    if lsof -i ":$TCP_PORT" -sTCP:LISTEN &>/dev/null; then
        echo -e "${GREEN}>>> wparse 已就绪 (端口 $TCP_PORT)${NC}"
        break
    fi
    sleep 1
    if [ "$i" -eq 30 ]; then
        echo -e "${RED}错误: wparse 在 30s 内未能监听端口 $TCP_PORT${NC}"
        exit 1
    fi
done

# ---- 3. 启动 wpgen (波动数据 → tcp_sink) ----
echo -e "${GREEN}>>> [3/3] 启动 wpgen (波动数据 → TCP :$TCP_PORT)...${NC}"
"$WPGEN_BIN" sample --work-root "$DEMO_DIR" --print_stat &
WPGEN_PID=$!

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  long-demo 运行中${NC}"
echo -e "${GREEN}  wparse PID: $WPARSE_PID  (TCP :$TCP_PORT)${NC}"
echo -e "${GREEN}  wpgen  PID: $WPGEN_PID${NC}"
echo -e "${GREEN}  Ctrl+C 停止${NC}"
echo -e "${GREEN}==========================================${NC}"

# ---- 等待任一进程退出 ----
wait "$WPARSE_PID" "$WPGEN_PID" 2>/dev/null || true
