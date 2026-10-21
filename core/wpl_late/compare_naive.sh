#!/usr/bin/env bash
set -euo pipefail

# 反事实对照：把同一个用例复制到临时的 work-root，去掉 #[late] 后重跑，
# 验证「兜底规则声明在最前 + 没有 #[late]」会吃掉所有事件。
#
# 期望：fallback = 100%，metrics / kv / json = 0。

CASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CASE_DIR"

for cmd in wparse wpgen wpadm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Command '$cmd' not found in PATH"
    exit 1
  fi
done

LINE_CNT=${LINE_CNT:-2000}
STAT_SEC=${STAT_SEC:-2}

# 临时 work-root 必须放在用例目录内：wpgen / wparse 会沿目录树向上查找
# wp-examples/connectors，放到系统临时目录会找不到连接器。
WORK_ROOT="$CASE_DIR/.naive_work"
rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"
cleanup() { rm -rf "$WORK_ROOT"; }
trap cleanup EXIT

cp -R conf models topology "$WORK_ROOT/"

# 去掉 #[late]（BSD/GNU sed 都不带 -i，避免平台差异）
sed 's/^[[:space:]]*#\[late\][[:space:]]*$//' \
  models/wpl/late_demo/parse.wpl > "$WORK_ROOT/models/wpl/late_demo/parse.wpl"
if grep -qE '^[[:space:]]*#\[late\][[:space:]]*$' "$WORK_ROOT/models/wpl/late_demo/parse.wpl"; then
  echo "failed to strip #[late] from the temporary copy"
  exit 1
fi

cd "$WORK_ROOT"

echo "1> gen sample data into $WORK_ROOT"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"
test -s "./data/in_dat/gen.dat" || { echo "missing gen.dat"; exit 1; }

echo "2> parse WITHOUT #[late]"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
  echo "wparse work failed. check $WORK_ROOT/data/logs/wparse.log"
  exit 1
fi

echo "3> expectation: fallback swallows everything"
FAIL=0
count_of() { if [ -f "./data/out_dat/$1" ]; then wc -l < "./data/out_dat/$1"; else echo 0; fi; }

fallback=$(count_of "fallback.dat")
for f in metrics.dat kv.dat json.dat; do
  n=$(count_of "$f")
  echo "  $f = $n (expect 0)"
  if [ "$n" -ne 0 ]; then FAIL=1; fi
done
echo "  fallback.dat = $fallback (expect $LINE_CNT)"
if [ "$fallback" -ne "$LINE_CNT" ]; then FAIL=1; fi

# 保留对照实验的产物，方便人工查看
if [ "${KEEP_NAIVE_OUT:-0}" = "1" ]; then
  mkdir -p "$CASE_DIR/data/naive_out_dat"
  cp ./data/out_dat/*.dat "$CASE_DIR/data/naive_out_dat/" 2>/dev/null || true
  echo "  naive outputs kept at ./data/naive_out_dat/"
fi

if [ "$FAIL" -ne 0 ]; then
  echo
  echo "UNEXPECTED: without #[late] the fallback did not swallow the stream."
  echo "            this means the fallback is no longer tried first — check rule ordering."
  exit 1
fi

echo
echo "confirmed: 没有 #[late] 时，声明在最前面的兜底规则吃掉了全部 $LINE_CNT 条事件。"
