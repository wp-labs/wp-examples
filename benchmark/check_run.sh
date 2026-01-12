#!/usr/bin/env bash
set -euo pipefail

# benchmark 检查脚本
# 遍历所有 case 下的测试场景，使用 -m 参数运行小数据测试

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 统计变量
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_LIST=()

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Benchmark Check - Small Data Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 遍历所有 case 目录
for case_dir in case_*/; do
  if [ ! -d "$case_dir" ]; then
    continue
  fi

  case_name=$(basename "$case_dir")
  echo -e "${YELLOW}检查 $case_name ...${NC}"

  # 遍历每个 case 下的测试场景目录
  for test_dir in "$case_dir"*/; do
    if [ ! -d "$test_dir" ]; then
      continue
    fi

    test_name=$(basename "$test_dir")

    # 跳过非测试目录
    if [[ "$test_name" == "sources" ]] || \
       [[ "$test_name" == "cases" ]] || \
       [[ "$test_name" == "topology" ]] || \
       [[ "$test_name" == "*.md" ]]; then
      continue
    fi

    # 检查是否存在 run.sh
    run_script="$test_dir/run.sh"
    if [ ! -f "$run_script" ]; then
      continue
    fi

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    test_path="$case_name/$test_name"

    echo -e "  ${BLUE}→${NC} 运行 $test_path ..."

    # 进入测试目录并执行 run.sh -m
    cd "$test_dir"

    if bash run.sh -m > /tmp/check_run_$$.log 2>&1; then
      echo -e "    ${GREEN}✓${NC} $test_path 通过"
      PASSED_TESTS=$((PASSED_TESTS + 1))
    else
      echo -e "    ${RED}✗${NC} $test_path 失败"
      FAILED_TESTS=$((FAILED_TESTS + 1))
      FAILED_LIST+=("$test_path")
      echo -e "    ${YELLOW}查看日志: /tmp/check_run_$$.log${NC}"
    fi

    cd "$SCRIPT_DIR"
    echo ""
  done
done

# 打印总结
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}测试总结${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "总测试数: $TOTAL_TESTS"
echo -e "${GREEN}通过: $PASSED_TESTS${NC}"
echo -e "${RED}失败: $FAILED_TESTS${NC}"

if [ $FAILED_TESTS -gt 0 ]; then
  echo ""
  echo -e "${RED}失败的测试:${NC}"
  for failed in "${FAILED_LIST[@]}"; do
    echo -e "  ${RED}✗${NC} $failed"
  done
  exit 1
else
  echo ""
  echo -e "${GREEN}所有测试通过！${NC}"
  exit 0
fi
