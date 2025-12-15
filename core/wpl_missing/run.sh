#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/run_common.sh"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-1000}
STAT_SEC=${STAT_SEC:-2}

# 初始化环境（清理运行输出但保留 conf 与模板）
core_usecase_bootstrap "${1:-debug}" keep_conf wparse wpgen wproj

echo "1> init wparse service"

# 初始化配置与数据目录
wproj  check
wproj data clean || true
wpgen data clean || true
# 旧 wpcfg 已合并至 wproj model；此处无需模型构建，保留为空

echo "2> gen sample data"
wpgen sample -n "$LINE_CNT"

echo "3> configure and start wparse work"
# 旧 wpcfg 已合并至 wproj model；此处无需模型构建，保留为空

wparse batch --stat "$STAT_SEC" -p

wproj  data stat
wproj  data validate
