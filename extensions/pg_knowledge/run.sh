#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

for cmd in docker wpgen wpadm wparse grep wc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

compose=(docker compose -p wp_examples_pg_knowledge -f docker-compose.yml)
line_cnt=${LINE_CNT:-100000}
gen_speed=${GEN_SPEED:-20000}
wparse_stat_sec=${WPARSE_STAT_SEC:-5}
output_file="./data/out_dat/pg_enriched.json"
wparse_pid_file="./.run/wparse.pid"

cleanup() {
    if [ -f "$wparse_pid_file" ]; then
        kill -TERM "$(cat "$wparse_pid_file")" >/dev/null 2>&1 || true
    fi
    "${compose[@]}" down -v >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "1> start postgres"
"${compose[@]}" up -d

echo "2> wait postgres ready"
for _ in {1..60}; do
    if "${compose[@]}" exec -T postgres pg_isready -U demo -d knowdb_demo >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! "${compose[@]}" exec -T postgres pg_isready -U demo -d knowdb_demo >/dev/null 2>&1; then
    echo "Error: postgres is not ready"
    exit 1
fi

echo "3> check project"
wpadm check --work-root "$(pwd)"

echo "4> clean runtime artifacts"
rm -rf ./.run ./data/out_dat ./data/logs
mkdir -p ./.run ./data/out_dat ./data/logs

echo "5> start wparse daemon"
wparse deamon --work-root "$(pwd)" --stat "$wparse_stat_sec" &

for _ in {1..50}; do
    if [ -f "$wparse_pid_file" ]; then
        break
    fi
    sleep 0.2
done

if [ ! -f "$wparse_pid_file" ]; then
    echo "Error: wparse daemon pid file not found"
    exit 1
fi

sleep 2

echo "6> send sample data over tcp"
wpgen sample --work-root "$(pwd)" -n "$line_cnt" -s "$gen_speed"

echo "7> wait output drain"
output_lines=0
for _ in {1..60}; do
    if [ -f "$output_file" ]; then
        output_lines=$(wc -l < "$output_file" | tr -d '[:space:]')
        if [ "$output_lines" = "$line_cnt" ]; then
            break
        fi
    fi
    sleep 1
done

if [ -f "$wparse_pid_file" ]; then
    kill -TERM "$(cat "$wparse_pid_file")" >/dev/null 2>&1 || true
fi

sleep 2

if [ ! -f "$output_file" ]; then
    echo "Error: output file not found: $output_file"
    exit 1
fi

echo "8> verify enrichment output"
grep -q '"asset_name":"edge-gateway-01"' "$output_file"
grep -q '"asset_env":"prod"' "$output_file"
grep -q '"asset_owner":"secops"' "$output_file"
grep -q '"asset_name":"internal-api-01"' "$output_file"
grep -q '"asset_env":"staging"' "$output_file"
grep -q '"asset_owner":"platform"' "$output_file"

output_lines=$(wc -l < "$output_file" | tr -d '[:space:]')
if [ "$output_lines" != "$line_cnt" ]; then
    echo "Error: output lines $output_lines != expected $line_cnt"
    exit 1
fi

echo "9> show data stat"
wpadm data stat --work-root "$(pwd)"
wpadm data validate --work-root "$(pwd)" --input-cnt "$line_cnt"

echo "OK: PostgreSQL knowledge enrichment example passed (lines=$line_cnt speed=$gen_speed)"
