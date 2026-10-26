#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 阶段 1：制造故障，抢救急文件；阶段 2：回放救援文件。
# 两个阶段都各自带守恒断言，任一失败即整体失败。
./case_interrupt.sh
./case_recovery.sh
