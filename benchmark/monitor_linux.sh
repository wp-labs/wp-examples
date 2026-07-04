#!/bin/bash
# monitor.sh (v6 - 仅 CPU/内存均值与峰值)
# 保留核心功能：监控指定进程的 CPU 与内存，输出平均值和峰值。
show_help() {
    cat << EOF
用法: $0 <进程名> [监控间隔] [总时长] [输出文件]

参数说明:
  进程名       必填，要监控的进程名称 (例如 vector, wpflow)
  监控间隔     采样间隔秒数 (默认: 1 秒)
  总时长       监控总时长秒数 (默认: 30 秒)
  输出文件     监控结果保存路径 (默认: monitoring_report.txt)

示例:
  $0 vector
      # 监控 vector 进程，间隔 1 秒，总时长 30 秒

  $0 wpflow 2 60 wpflow_report.txt
      # 监控 wpflow 进程，间隔 2 秒，总时长 60 秒，结果保存到 wpflow_report.txt
EOF
}

# --- 如果传 -h 或 --help 就打印帮助并退出 ---
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# --- 参数解析（带默认值） ---
PROCESS_NAME=${1}
INTERVAL=${2:-1}
DURATION=${3:-30}
OUTFILE=${4:-"monitoring_report.txt"}

if [ -z "$PROCESS_NAME" ]; then
    echo "错误: 必须提供要监控的进程名作为第一个参数。" >&2
    echo "使用 $0 --help 查看帮助。" >&2
    exit 1
fi

echo "--- [1/3] 正在查找进程 '$PROCESS_NAME' ---"

# 确保 pidstat 可用；若缺失则尝试安装（需具备相应权限）
if ! command -v pidstat >/dev/null 2>&1; then
    echo "未找到 pidstat，尝试安装..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y sysstat
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y sysstat
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y sysstat
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y sysstat
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm sysstat
    else
        echo "无法自动安装 pidstat，请手动安装 sysstat 包后重试。" >&2
        exit 1
    fi

    if ! command -v pidstat >/dev/null 2>&1; then
        echo "自动安装 pidstat 失败，请手动安装 sysstat 包后重试。" >&2
        exit 1
    fi
    echo "pidstat 已安装。"
fi

PIDS=$(pgrep -x "$PROCESS_NAME")

if [ -z "$PIDS" ]; then
    echo "错误: 找不到正在运行的 '$PROCESS_NAME' 进程。" >&2
    exit 1
fi

pid_count=$(echo "$PIDS" | wc -l | xargs)
if [ "$pid_count" -gt 1 ]; then
    echo "⚠️ 发现多个 '$PROCESS_NAME' 进程，请选择一个："
    select pid in $PIDS; do
        if [ -n "$pid" ]; then
            break
        fi
    done
else
    pid=$PIDS
fi

echo "✅ 成功找到进程，PID: $pid"
echo "----------------------------------"

# --- 2. 执行监控 ---
echo "--- [2/3] 开始监控 ---"
echo "监控进程名: $PROCESS_NAME"
echo "监控 PID:   $pid"
echo "采样间隔:   $INTERVAL 秒"
echo "总时长:     $DURATION 秒"
echo "结果将写入: $OUTFILE"
echo "----------------------------------"

cpu_sum=0
cpu_max=0
mem_sum=0
mem_max=0
count=0

start_time=$(date +%s)
end_time=$((start_time + DURATION))

> "$OUTFILE"

while [ "$(date +%s)" -lt "$end_time" ]; do
    if ! ps -p "$pid" > /dev/null; then
        echo "⚠️ 目标进程 PID '$pid' 已退出，监控提前结束。" >&2
        break
    fi

    read -r cpu mem_kb < <(pidstat -u -r -p "$pid" 1 1 | awk '
        /%CPU/ { getline; cpu_val=$8 }
        /RSS/  { getline; mem_val=$7 }
        END    { if (cpu_val == "") cpu_val="N/A"; if (mem_val == "") mem_val="N/A"; print cpu_val, mem_val }
    ')

    if [[ "$cpu" =~ ^[0-9]+([.][0-9]+)?$ && "$mem_kb" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        mem_mb=$(awk "BEGIN {print $mem_kb / 1024}")
        printf "实时: CPU %5.1f%% | Mem %8.2f MB\n" "$cpu" "$mem_mb"

        cpu_sum=$(awk "BEGIN {print $cpu_sum + $cpu}")
        mem_sum=$(awk "BEGIN {print $mem_sum + $mem_mb}")

        cpu_max=$(awk "BEGIN {print ($cpu > $cpu_max) ? $cpu : $cpu_max}")
        mem_max=$(awk "BEGIN {print ($mem_mb > $mem_max) ? $mem_mb : $mem_max}")

        count=$((count + 1))
    else
        echo "⚠️ 无法从 pidstat 输出中获取有效数据。CPU='$cpu', Mem='$mem_kb'" >&2
    fi

    sleep "$INTERVAL"
done

echo "----------------------------------"
echo "--- [3/3] 生成监控报告 ---"

if [ $count -eq 0 ]; then
    echo "❌ 错误: 没有采集到任何有效数据。" >&2
    exit 1
fi

cpu_avg=$(awk "BEGIN {print $cpu_sum/$count}")
mem_avg=$(awk "BEGIN {print $mem_sum/$count}")

{
    echo "========== 性能监控汇总 =========="
    echo "监控时间: $(date)"
    echo "进程名:   $PROCESS_NAME"
    echo "PID:      $pid"
    echo "采样次数: $count 次"
    echo "------------------------------------"
    printf "平均 CPU 使用率: %.2f %%\n" "$cpu_avg"
    printf "峰值 CPU 使用率: %.2f %%\n" "$cpu_max"
    echo "------------------------------------"
    printf "平均内存使用 (RSS): %.2f MB\n" "$mem_avg"
    printf "峰值内存使用 (RSS): %.2f MB\n" "$mem_max"
    echo "===================================="
} > "$OUTFILE"

echo "✅ 监控结束，汇总报告已保存到: $OUTFILE"
echo 
cat "$OUTFILE"
