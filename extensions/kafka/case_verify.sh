#!/usr/bin/env bash
set -euo pipefail

# 加载公共函数库
COMMON_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"
source "$COMMON_LIB"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-3000}
STAT_SEC=${STAT_SEC:-3}

# 初始化环境
init_script_dir
parse_profile "${1:-debug}"

echo "1> init (clean/build/path)"
# 清理运行输出但保留用例的 wpl/oml/source/sink 模板
clean_runtime_dirs keep_conf

# 预构建，避免多次调用触发重复编译；并将 target/<profile> 加入 PATH 直接调用二进制
build_and_setup_path
verify_commands wparse wpgen wpkit

echo "2> check conf & clean data"
wpkit conf check
wpkit data clean || true
wpgen data clean || true

# Kafka 参数（与 connectors/source.d/30-kafka.toml、tests 中保持一致）
KAFKA_BOOTSTRAP_SERVERS=${KAFKA_BOOTSTRAP_SERVERS:-${KAFKA_BROKERS:-"localhost:9092"}}
KAFKA_INPUT_TOPIC=${KAFKA_INPUT_TOPIC:-${TOPIC_IN:-"wp.testcase.events.raw"}}
KAFKA_OUTPUT_TOPIC=${KAFKA_OUTPUT_TOPIC:-${TOPIC_OUT:-"wp.testcase.events.parsed"}}

echo "3> start wparse (profile=$PROFILE, n=$LINE_CNT)"
# 先启动消费，再发送数据；使用 -n 限制条数，处理完成后自动退出
(
  set -e
  if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
    echo "wparse work failed. check ./logs/wparse.log and ./logs/wparse.stdout (if exists)."
    exit 1
  fi
) &
WPARSE_BG_PID=$!
sleep 0.5

echo "4> generate $LINE_CNT events via wpgen (to Kafka: $KAFKA_INPUT_TOPIC)"
# wpgen.conf 已配置 output.connect = "kafka_sink"，并在 params_override 中覆写 topic
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"

echo "5> wait wparse to finish"
wait "$WPARSE_BG_PID" || {
  echo "wparse did not exit cleanly"
  exit 1
}

echo "6> validate file sinks by expect (sanity check)"
# 仍保留文件型 sink 校验，便于本地快速断言处理链路
wpkit stat file || true
wpkit validate sink-file -v || true
