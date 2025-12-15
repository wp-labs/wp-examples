#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 初始化环境（清理运行输出但保留 wpl/oml/source/sink 模板与 conf；同时确保依赖命令可用）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj

echo "1> init wparse service"

echo "1> init conf & data"
# 初始化配置与数据目录
wproj init
wproj data clean ;
wpgen  conf clean || true
wpgen  conf init
wpgen  data clean || true

echo "2> gen file data"
wpgen  sample -n "$LINE_CNT" --stat "$STAT_SEC"

echo "3> verify inputs"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "4> start wparse work (profile=$PROFILE)"
  # 使用 -n 限制条数，确保用例自动退出；出错时打印日志辅助定位
  # 为避免长连接类源（如 syslog_udp_src）阻滞退出，缩短停止检测周期：-S 1
  if ! wparse batch --stat "$STAT_SEC" -S 1 -p -n "$LINE_CNT"; then
    echo "wparse work failed. check ./logs/wparse.log and ./logs/wparse.stdout (if exists)."
    exit 1
  fi


echo "6> validate sinks by expect "
# 使用 --input-cnt 显式指定总输入条数（便于 total_input 口径场景），组级为 group_input 时会自动回退到组内口径

wproj  data stat
wproj  data validate
