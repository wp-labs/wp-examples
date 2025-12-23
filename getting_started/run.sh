#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 验证必要的命令存在
for cmd in wparse wpgen wproj; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

echo "1> init wparse service"
# 清理已存在的目录
rm -rf conf models topology data || true

echo "1> init conf & data"
# 初始化配置与数据目录
wproj init
wproj data clean
wpgen conf clean || true
wpgen conf init
wpgen data clean || true

echo "2> gen file data"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"

echo "3> verify inputs"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "4> start wparse work"
# 使用 -n 限制条数，确保用例自动退出；出错时打印日志辅助定位
# 为避免长连接类源（如 syslog_udp_src）阻滞退出，缩短停止检测周期：-S 1
if ! wparse batch --stat "$STAT_SEC" -S 1 -p -n "$LINE_CNT"; then
    echo "wparse work failed. check ./logs/wparse.log and ./logs/wparse.stdout (if exists)."
    exit 1
fi

echo "5> validate sinks"
# 使用 --input-cnt 显式指定总输入条数（便于 total_input 口径场景），组级为 group_input 时会自动回退到组内口径
wproj data stat
wproj data validate
