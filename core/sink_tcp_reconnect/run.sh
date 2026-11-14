#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 覆盖场景：发送端（wparse）持续发送，接收端进程中途退出并在同一端口恢复。
# 断言发送端不重启也能继续投递（TCP 与 TLS 各跑一轮）。
PROTOCOL=${PROTOCOL:-both}          # tcp | tls | both
LINE_CNT=${LINE_CNT:-40000}         # 输入行数（rate_limit_rps=2000，约 20s）
GEN_SPEED=${GEN_SPEED:-20000}
OUTAGE_SECS=${OUTAGE_SECS:-3}       # 接收端停机时长
STAT_SEC=${STAT_SEC:-2}
TCP_PORT=${TCP_PORT:-19100}
TLS_PORT=${TLS_PORT:-19101}

RECV_DIR="./data/recv"
SINK_FILE="./topology/sinks/business.d/benchmark.toml"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

line_count() {
    if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi
}

# 日志可能因体积触发 gzip 轮转（10MB），断言要覆盖所有分片。
log_grep() {
    local pat=$1 f
    for f in data/logs/wparse.log*; do
        [ -f "$f" ] || continue
        case "$f" in
            *.gz) zgrep -q "$pat" "$f" 2>/dev/null && return 0 ;;
            *) grep -q "$pat" "$f" 2>/dev/null && return 0 ;;
        esac
    done
    return 1
}

log_dropped_total() {
    local total=0 f n
    for f in data/logs/wparse.log*; do
        [ -f "$f" ] || continue
        case "$f" in
            *.gz) n=$(zgrep -ho 'dropped [0-9]* record(s) since' "$f" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}') ;;
            *) n=$(grep -ho 'dropped [0-9]* record(s) since' "$f" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}') ;;
        esac
        total=$(( total + ${n:-0} ))
    done
    echo "$total"
}

for cmd in wparse wpgen wpadm python3; do
    command -v "$cmd" >/dev/null 2>&1 || die "command '$cmd' not found in PATH"
done
if [ "$PROTOCOL" != "tcp" ]; then
    command -v openssl >/dev/null 2>&1 || die "openssl is required for the TLS phase"
fi

lsof_kill_port() {
    local port=$1
    if command -v lsof >/dev/null 2>&1; then
        lsof -t -nP -iTCP:"$port" 2>/dev/null | xargs -r kill -9 2>/dev/null || true
    fi
}

gen_certs() {
    mkdir -p data/tls
    openssl req -x509 -newkey rsa:2048 -sha256 -days 2 -nodes \
        -keyout data/tls/key.pem -out data/tls/cert.pem \
        -subj "/CN=localhost" >/dev/null 2>&1
}

RECV_PID=""
WPARSE_PID=""

cleanup() {
    if [ -n "$RECV_PID" ] && kill -0 "$RECV_PID" 2>/dev/null; then
        kill "$RECV_PID" 2>/dev/null || true
    fi
    if [ -n "$WPARSE_PID" ] && kill -0 "$WPARSE_PID" 2>/dev/null; then
        kill "$WPARSE_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

start_receiver() {
    local proto=$1 port=$2 out=$3
    local ready="$RECV_DIR/$proto.ready"
    local args=(--host 127.0.0.1 --port "$port" --out "$out" --ready-file "$ready")
    if [ "$proto" = "tls" ]; then
        args+=(--tls-cert data/tls/cert.pem --tls-key data/tls/key.pem)
    fi
    rm -f "$ready"
    python3 receiver.py "${args[@]}" &
    RECV_PID=$!
    for _ in $(seq 1 50); do
        [ -f "$ready" ] && return 0
        sleep 0.1
    done
    die "receiver($proto) did not become ready on port $port"
}

stop_receiver() {
    local proto=$1
    if [ -n "${RECV_PID:-}" ] && kill -0 "$RECV_PID" 2>/dev/null; then
        kill "$RECV_PID" 2>/dev/null || true
        wait "$RECV_PID" 2>/dev/null || true
    fi
    RECV_PID=""
    rm -f "$RECV_DIR/$proto.ready"
}

run_phase() {
    local proto=$1 port=$2
    echo "---- phase protocol=${proto} port=${port}"

    lsof_kill_port "$port"
    cp "topology/sink_profiles/$proto.toml" "$SINK_FILE"

    rm -rf data/out_dat data/logs "$RECV_DIR"
    wpadm data clean >/dev/null
    wpgen data clean >/dev/null
    mkdir -p data/logs "$RECV_DIR" data/out_dat
    rm -rf data/rescue
    mkdir -p data/rescue

    if [ "$proto" = "tls" ]; then
        gen_certs
    fi

    wpgen sample -n "$LINE_CNT" -s "$GEN_SPEED" --stat 1 >/dev/null

    local out="$RECV_DIR/$proto.dat"
    start_receiver "$proto" "$port" "$out"

    wparse batch --stat "$STAT_SEC" --print_stat >/dev/null 2>&1 &
    WPARSE_PID=$!
    local wparse_rc=0

    # 让数据流建立起来，然后模拟接收端进程退出
    sleep 3
    stop_receiver "$proto"
    if [ -f "$out" ]; then mv "$out" "$RECV_DIR/$proto.phase1.dat"; fi
    sleep "$OUTAGE_SECS"

    # 接收端在同一端口恢复
    start_receiver "$proto" "$port" "$out"
    sleep 4

    kill -0 "$WPARSE_PID" 2>/dev/null \
        || die "[$proto] wparse exited during the outage; the sender must keep running"
    wait "$WPARSE_PID" || wparse_rc=$?
    WPARSE_PID=""
    [ "$wparse_rc" -eq 0 ] || die "[$proto] wparse batch failed (rc=$wparse_rc)"

    stop_receiver "$proto"
    if [ -f "$out" ]; then mv "$out" "$RECV_DIR/$proto.phase2.dat"; fi

    local p1 p2 input example infra dropped rescue_files
    p1=$(line_count "$RECV_DIR/$proto.phase1.dat")
    p2=$(line_count "$RECV_DIR/$proto.phase2.dat")
    input=$(line_count ./data/in_dat/gen.dat)
    example=$(line_count ./data/out_dat/example.dat)
    infra=$(( $(line_count ./data/out_dat/miss.dat) + $(line_count ./data/out_dat/residue.dat) + $(line_count ./data/out_dat/error.dat) ))
    dropped=$(log_dropped_total)
    rescue_files=$(find data/rescue -type f 2>/dev/null | wc -l | tr -d ' ')

    echo "check(${proto}): input=${input} phase1=${p1} phase2=${p2} example=${example} infra=${infra} dropped=${dropped} rescue=${rescue_files}"

    [ "$input" -gt 0 ] || die "[$proto] input is empty"
    [ "$p1" -gt 0 ] || die "[$proto] receiver got no data before the outage"
    [ "$p2" -gt 0 ] || die "[$proto] receiver got no data after restart: auto-reconnect did not work"
    [ "$rescue_files" -eq 0 ] || die "[$proto] drop_when_error must not create rescue files"
    log_grep "tcp sink reconnected" \
        || die "[$proto] wparse.log: no 'tcp sink reconnected'; connector did not rebuild the link"
    log_grep "recovered from send failures" \
        || die "[$proto] wparse.log: breaker never recovered; the sink stayed broken"

    # TCP 无应用层 ACK，且 drop_when_error 按“批”记账：
    # - 接收端消失时，已进入内核缓冲的数据可能既未送达也未记账（lost 略大）；
    # - 失败批次里已写入的记录也可能被计入 dropped（dropped 略大）。
    # 因此不做精确守恒，只校验 delivered+dropped 与 input 的偏差在容差内。
    local delivered=$(( example + p1 + p2 + infra ))
    local lost=$(( input - delivered ))
    local covered=$(( delivered + dropped ))
    local tol=${ACCOUNT_TOL:-4096}
    [ "$delivered" -le "$input" ] \
        || die "[$proto] delivered ${delivered} exceeds input ${input}"
    [ "$lost" -gt 0 ] || die "[$proto] expected data loss during the outage, got 0"
    [ "$dropped" -gt 0 ] || die "[$proto] expected records dropped during the outage, got 0"
    [ "$covered" -ge $(( input - tol )) ] \
        || die "[$proto] accounting under-reports: delivered+dropped=${covered} input=${input} (tol=${tol})"
    [ "$covered" -le $(( input + tol )) ] \
        || die "[$proto] accounting over-reports: delivered+dropped=${covered} input=${input} (tol=${tol})"
    echo "check(${proto}): delivered=${delivered} lost=${lost} dropped=${dropped} covered=${covered} tol=${tol}"
}

case "$PROTOCOL" in
    tcp|tls|both) ;;
    *) die "PROTOCOL must be 'tcp', 'tls' or 'both' (got '$PROTOCOL')" ;;
esac

wpadm check
wpadm init --mode data >/dev/null
rm -rf data/rescue
mkdir -p data/rescue

case "$PROTOCOL" in
    tcp) run_phase tcp "$TCP_PORT" ;;
    tls) run_phase tls "$TLS_PORT" ;;
    both)
        run_phase tcp "$TCP_PORT"
        run_phase tls "$TLS_PORT"
        ;;
esac

# 恢复仓库内的默认配置，避免 run.sh 修改后的状态被误提交
cp topology/sink_profiles/tcp.toml "$SINK_FILE"

echo "OK: TCP/TLS sink reconnects after receiver restart without restarting wparse (protocol=${PROTOCOL})"
