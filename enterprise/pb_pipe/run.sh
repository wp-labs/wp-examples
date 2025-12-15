#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-30}
STAT_SEC=${STAT_SEC:-3}

# 初始化环境（保留 conf 以复用示例配置）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj

echo "1> init wparse service"

echo "1> init conf & data"
wproj check || true
wproj data clean || true
wpgen data clean || true

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"

echo "3> verify inputs"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "4> start wparse work (profile=$PROFILE)"
if ! wparse batch --stat "$STAT_SEC" -p ; then
  echo "wparse work failed. check ./data/logs/wparse.log"
  exit 1
fi

echo "6> validate sinks by expect "
wproj data stat
wproj data validate
