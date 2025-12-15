#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 初始化环境（清理运行输出但保留 conf）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj

echo "1> init wparse service"
# 强制刷新 conf（只移除 wparse.toml，由 wproj 重新生成），避免旧版键位导致校验失败
wproj check|| true

# 初始化配置与数据目录
wproj data clean || true
wpgen data clean || true

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"

echo "3> verify inputs"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "4> start wparse work (profile=$PROFILE)"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
  echo "wparse work failed. check ./data/logs/wparse.log"
  exit 1
fi

echo "6> validate sinks by expect "
wproj data stat
wproj data validate
