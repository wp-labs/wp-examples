#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}

# 初始化环境（保留 conf 但刷新 wparse.toml）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj curl

echo "1> init wparse service"
# 清理运行输出；保留其他目录但强制刷新 conf/wparse.toml 以应用新版键位（core_usecase_bootstrap 已执行）

wproj data clean || true
rm -f prometheus_monitor.dat

echo "2> start wparse work (syslog receiver)"
wparse deamon --stat 2  -p &
echo "Waiting for wparse (syslog:1514) and prometheus exporter to start..."
sleep 3

echo "3> gen sample data (send to syslog)"
wpgen sample -n $LINE_CNT --stat 1 -p
#echo "4> request monitor"
#curl -X GET 'http://localhost:35666/metrics' >> prometheus_monitor.dat
echo "5> stop wparse"
# wparse 仅监听 SIGTERM/SIGQUIT/SIGINT（三选一）；SIGHUP(-1)不会触发优雅退出
# 发送 SIGTERM 并等待进程退出
if [ -f ./.run/wparse.pid ]; then
  pid=$(cat ./.run/wparse.pid)
  kill -TERM "$pid" 2>/dev/null || true
fi

sleep 5

wproj  data stat
wproj  data validate  --input-cnt $LINE_CNT
