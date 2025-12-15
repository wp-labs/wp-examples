#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"


# 初始化环境（保留 conf 以加载自带的 KnowDB 配置）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj

echo "1> init wparse service"

# 参数（可通过环境变量覆盖）
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}
GEN_SPEED=${GEN_SPEED:-200}   # 适度限速，降低 UDP 丢包概率

# 配置准备
wproj  check || true
wproj  data clean
wpgen  conf check
wpgen  data clean


#wparse batch --stat "$STAT_SEC" --print_stat &
# 启动 wparse（后台，UDP 接收需常驻）
#trap 'bg_cleanup ./.run/wparse.pid' EXIT
wparse daemon --stat "$STAT_SEC" --print_stat &
wait_for_pid_file ./.run/wparse.pid || true
sleep 1   # 简短预热，避免启动窗口丢包


# 发送样本并校验
wpgen rule -n "$LINE_CNT" -s "$GEN_SPEED"
sleep 2   # 等待数据排空

# 停止服务与校验输出
bg_cleanup ./.run/wparse.pid || true
sleep 3   # 等待数据排空
wproj data stat
wproj data validate  --input-cnt $LINE_CNT
