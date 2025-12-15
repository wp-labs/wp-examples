
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-1}

# 初始化环境（清理运行输出但保留 dvl/oml/source/sink 模板）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen

echo "1> init wparse service"

# 初始化配置与数据目录
wproj check
wproj data clean || true
wpgen data clean || true

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC" -p

echo "3> start wparse work"
wparse batch --stat "$STAT_SEC" -p

wproj data stat
wproj data validate
