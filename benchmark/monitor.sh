#!/usr/bin/env bash
# macOS 进程 CPU/内存监控（流式输出 + 平均统计）
# 用法:
#   ./monitor.sh "<进程名或关键字>" [间隔秒=1]
# 示例:
#   ./monitor.sh wparse
#   ./monitor.sh "python3 wpgen_sender.py" 0.5

set -euo pipefail

KEYWORD="${1:-}"
INTERVAL="${2:-1}"

if [[ -z "$KEYWORD" ]]; then
  echo "用法: $0 \"<process_keyword>\" [interval_sec]" >&2
  exit 1
fi

# 查找匹配 PID
get_pids() {
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "$KEYWORD" 2>/dev/null || true
  else
    ps ax -o pid= -o command= | grep -E "$KEYWORD" | grep -v grep | awk '{print $1}'
  fi
}

# 获取单个 PID 的 %CPU 和 RSS(KB)
read_cpu_rss() {
  local pid="$1"
  local line
  line="$(ps -p "$pid" -o %cpu= -o rss= 2>/dev/null | awk '{printf "%s %s",$1,$2}')"
  [[ -z "$line" ]] && { echo "0 0"; return; }
  echo "$line"
}

echo "监控目标: \"$KEYWORD\"  每 ${INTERVAL}s 采样一次（macOS）"
printf "%-19s | %6s | %12s | %12s\n" "时间" "实例数" "CPU合计(%)" "RSS合计(MB)"
echo "-------------------+--------+--------------+--------------"

# 初始化统计变量
sample_cnt=0
cpu_sum=0
rss_sum=0
cpu_max=0
rss_max=0
gone_ticks=0

T_START=$(date +%s)

while :; do
  sleep "$INTERVAL"

  # 收集 PID
  PIDS=()
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && PIDS+=("$pid")
  done < <(get_pids)

  if ((${#PIDS[@]}==0)); then
    ((gone_ticks++))
    ts="$(date '+%F %T')"
    printf "%-19s | %6d | %12.1f | %12.2f\n" "$ts" 0 0.0 0.00
    if ((gone_ticks>=2)); then
      echo "进程不存在，结束监控。"
      break
    fi
    continue
  fi
  gone_ticks=0

  total_cpu=0
  total_rss_kb=0
  for pid in "${PIDS[@]}"; do
    read -r pcpu rsskb <<<"$(read_cpu_rss "$pid")"
    [[ "$pcpu" =~ ^[0-9]+([.][0-9]+)?$ ]] && \
      total_cpu=$(awk -v a="$total_cpu" -v b="$pcpu" 'BEGIN{printf "%.2f", a+b}')
    [[ "$rsskb" =~ ^[0-9]+$ ]] && \
      total_rss_kb=$(( total_rss_kb + rsskb ))
  done
  total_rss_mb=$(awk -v k="$total_rss_kb" 'BEGIN{printf "%.2f", k/1024}')
  CPU_MIN=30.0   # 小于 30.0% 的 CPU 视为无效
  ts="$(date '+%F %T')"
  # 剔除 CPU=0 且 RSS=0 的无效采样
  # 剔除 CPU 很小（噪声）或 RSS=0 的采样
  if awk -v cpu="$total_cpu" -v min="$CPU_MIN" 'BEGIN{exit !(cpu < min)}'; then
    continue
  fi
  printf "%-19s | %6d | %12.1f | %12.2f\n" "$ts" "${#PIDS[@]}" "$total_cpu" "$total_rss_mb"

  # 累计
  cpu_sum=$(awk -v a="$cpu_sum" -v b="$total_cpu" 'BEGIN{printf "%.2f", a+b}')
  rss_sum=$(awk -v a="$rss_sum" -v b="$total_rss_mb" 'BEGIN{printf "%.2f", a+b}')
  ((sample_cnt++))

  # 峰值
  cpu_max=$(awk -v a="$cpu_max" -v b="$total_cpu" 'BEGIN{printf "%.2f", (b>a)?b:a}')
  rss_max=$(awk -v a="$rss_max" -v b="$total_rss_mb" 'BEGIN{printf "%.2f", (b>a)?b:a}')
done

T_END=$(date +%s)
DURATION=$((T_END - T_START))

# 计算平均值
if (( sample_cnt > 0 )); then
  cpu_avg=$(awk -v s="$cpu_sum" -v n="$sample_cnt" 'BEGIN{printf "%.2f", s/n}')
  rss_avg=$(awk -v s="$rss_sum" -v n="$sample_cnt" 'BEGIN{printf "%.2f", s/n}')
else
  cpu_avg="0.00"
  rss_avg="0.00"
fi

echo "============== 汇总 =============="
printf "监控时长: %ds\n" "$DURATION"
printf "采样次数: %d\n" "$sample_cnt"
printf "平均CPU:  %s %%\n" "$cpu_avg"
printf "峰值CPU:  %.2f %%\n" "$cpu_max"
printf "平均RSS:  %s MB\n" "$rss_avg"
printf "峰值RSS:  %.2f MB\n" "$rss_max"
echo "=================================="