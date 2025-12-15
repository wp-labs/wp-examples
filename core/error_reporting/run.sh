#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 初始化环境（清理输出但保留 conf）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj

echo "1> init wparse service"
echo "1> init wparse service"
# 清理运行输出但保留 conf（自带 wpgen1/2.toml 与 wparse.toml，已由 core_usecase_bootstrap 执行）

echo "1> init conf & data"
# 保留 conf 目录中的 wpgen1.toml/wpgen2.toml 自定义生成配置
wproj check
# 该用例使用两个生成配置，保留双源生成方式
wproj data clean || true
wpgen data clean || true

echo "2> gen sample data"
wpgen sample  -n "$LINE_CNT" --stat "$STAT_SEC"

echo "3> verify inputs"

echo "4> start wparse work (profile=$PROFILE)"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
  echo "wparse work failed. check ./data/logs/wparse.log"
  exit 1
fi

echo "6> validate sinks by expect "
wproj data stat
wproj data validate
