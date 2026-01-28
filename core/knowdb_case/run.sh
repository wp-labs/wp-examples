#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 验证必要的命令存在
for cmd in wparse wpgen wproj; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

echo "1> init wparse service"

# 参数（可通过环境变量覆盖）
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}
GEN_SPEED=${GEN_SPEED:-200}   # 适度限速，降低 UDP 丢包概率

# 配置准备
wproj check || true
wproj data clean
wpgen conf check
wpgen data clean



# 发送样本并校验
wpgen rule -n "$LINE_CNT" -s "$GEN_SPEED"
sleep 2   # 等待数据排空

wparse batch --stat "$STAT_SEC" -p

# 停止服务
if [ -f ./.run/wparse.pid ]; then
    kill -TERM $(cat ./.run/wparse.pid) || true
fi
sleep 3   # 等待数据排空

wproj data stat
wproj data validate --input-cnt $LINE_CNT
