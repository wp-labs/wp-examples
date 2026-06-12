#!/usr/bin/env bash
set -euo pipefail

# 向达梦 HTTP 请求日志表写入指定数量的测试数据。
# 说明：
# 1. 优先使用 ODBC `isql` 执行 SQL，不再依赖 Python 的 dmPython 驱动。
# 2. `DM_DSN` 仅支持 ODBC DSN 名称或 ODBC 连接串；不再支持 dmPython 风格的 `user/password@host:port`。

TABLE_NAME="http_request_logs"
DEFAULT_BATCH_SIZE="1000"
DEFAULT_SERVER="127.0.0.1"
DEFAULT_PORT="5236"
DEFAULT_USER="SYSDBA"
DEFAULT_PASSWORD="SYSDBA"
TIMESTAMP_TZ_FORMAT="YYYY-MM-DD HH24:MI:SS.FF6 TZH:TZM"

DM_USER="${DMUSER:-$DEFAULT_USER}"
DM_PASSWORD="${DMPASSWORD:-$DEFAULT_PASSWORD}"
DM_SERVER="${DMSERVER:-$DEFAULT_SERVER}"
DM_PORT="${DMPORT:-$DEFAULT_PORT}"
DM_DSN_VALUE="${DM_DSN:-}"
SCHEMA_NAME="$(printf '%s' "${DMSCHEMA:-$DM_USER}" | tr '[:lower:]' '[:upper:]')"

die() {
    printf '%s\n' "$*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

validate_identifier() {
    case "$1" in
        [A-Za-z_][A-Za-z0-9_]*)
            ;;
        *)
            die "非法标识符：$1"
            ;;
    esac
}

parse_batch_size() {
    if [[ $# -eq 0 ]]; then
        printf '%s\n' "$DEFAULT_BATCH_SIZE"
        return
    fi

    if [[ $# -ne 1 ]]; then
        die "用法：bash $(basename "$0") [写入条数]"
    fi

    case "$1" in
        ''|*[!0-9]*)
            die "写入条数必须是正整数"
            ;;
        0)
            die "写入条数必须大于 0"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

qualified_table_name() {
    printf '%s.%s\n' "$SCHEMA_NAME" "$TABLE_NAME"
}

is_odbc_connection_string() {
    case "$1" in
        *"Driver="*|*"DRIVER="*|*"DSN="*|*"UID="*|*"PWD="*|*";"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

run_sql_file() {
    local sql_file="$1"
    local output

    require_cmd isql

    if [[ -n "$DM_DSN_VALUE" ]]; then
        if is_odbc_connection_string "$DM_DSN_VALUE"; then
            output="$(isql -b -v -k "$DM_DSN_VALUE" < "$sql_file" 2>&1)" || {
                printf '%s\n' "$output" >&2
                return 1
            }
        else
            case "$DM_DSN_VALUE" in
                *"@"*|*"/"*)
                    die "shell 版不支持 dmPython 风格的 DM_DSN，请改用 ODBC DSN 名称或 DMSERVER/DMPORT。"
                    ;;
                *)
                    output="$(isql -b "$DM_DSN_VALUE" "$DM_USER" "$DM_PASSWORD" < "$sql_file" 2>&1)" || {
                        printf '%s\n' "$output" >&2
                        return 1
                    }
                    ;;
            esac
        fi
    else
        output="$(isql -b -v -k "Driver={DM8 ODBC DRIVER};Server=${DM_SERVER};Port=${DM_PORT};UID=${DM_USER};PWD=${DM_PASSWORD};SCHEMA=${SCHEMA_NAME};" < "$sql_file" 2>&1)" || {
            printf '%s\n' "$output" >&2
            return 1
        }
    fi

    if printf '%s\n' "$output" | grep -q "\[ISQL\]ERROR:"; then
        printf '%s\n' "$output" >&2
        return 1
    fi

    if [[ -n "$output" ]]; then
        printf '%s\n' "$output"
    fi
}

extract_last_value() {
    awk '
        {
            line = $0
            gsub(/^[[:space:]\|]+/, "", line)
            gsub(/[[:space:]\|]+$/, "", line)
            if (line == "" || line ~ /^[-+]+$/) {
                next
            }
            if (line ~ /^[0-9]+$/) {
                last = line
            } else if (line ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} /) {
                last = line
            }
        }
        END {
            if (last != "") {
                print last
            }
        }
    '
}

query_single_value() {
    local sql_file
    local output

    sql_file="$(mktemp)"
    cat > "$sql_file"

    if ! output="$(run_sql_file "$sql_file" 2>&1)"; then
        rm -f "$sql_file"
        printf '%s\n' "$output" >&2
        exit 1
    fi

    rm -f "$sql_file"
    printf '%s\n' "$output" | extract_last_value
}

main() {
    validate_identifier "$SCHEMA_NAME"

    local batch_size
    local target_table
    local sql_file
    local total_rows
    local first_create_time
    local last_create_time

    batch_size="$(parse_batch_size "$@")"
    target_table="$(qualified_table_name)"
    sql_file="$(mktemp)"

    cat > "$sql_file" <<SQL
LOCK TABLE $target_table IN EXCLUSIVE MODE;
INSERT INTO $target_table ("sip", "timestamp", "http/request", "status", "create_time", "update_time") SELECT '10.' || MOD(TRUNC((base.base_id + seq.seq_no) / 65536), 256) || '.' || MOD(TRUNC((base.base_id + seq.seq_no) / 256), 256) || '.' || MOD(base.base_id + seq.seq_no, 256), base.base_create_time + NUMTODSINTERVAL(CAST(seq.seq_no AS DECIMAL(18,6)) / 1000000, 'SECOND'), 'GET /api/example/' || TO_CHAR(base.base_id + seq.seq_no) || ' HTTP/1.1', CASE WHEN MOD(base.base_id + seq.seq_no, 50) = 0 THEN 500 WHEN MOD(base.base_id + seq.seq_no, 17) = 0 THEN 404 ELSE 200 END, base.base_create_time + NUMTODSINTERVAL(CAST(seq.seq_no AS DECIMAL(18,6)) / 1000000, 'SECOND'), base.base_create_time + NUMTODSINTERVAL(CAST(seq.seq_no AS DECIMAL(18,6)) / 1000000, 'SECOND') FROM (SELECT NVL(MAX("id"), 0) AS base_id, NVL(MAX("create_time"), CURRENT_TIMESTAMP) AS base_create_time FROM $target_table) base, (SELECT LEVEL AS seq_no FROM DUAL CONNECT BY LEVEL <= $batch_size) seq;
COMMIT;
SQL

    if ! run_sql_file "$sql_file" >/dev/null; then
        rm -f "$sql_file"
        exit 1
    fi
    rm -f "$sql_file"

    total_rows="$(query_single_value <<SQL
SELECT COUNT(*) FROM $target_table;
SQL
)"

    first_create_time="$(query_single_value <<SQL
SELECT TO_CHAR(MIN("create_time"), '$TIMESTAMP_TZ_FORMAT') FROM $target_table;
SQL
)"

    last_create_time="$(query_single_value <<SQL
SELECT TO_CHAR(MAX("create_time"), '$TIMESTAMP_TZ_FORMAT') FROM $target_table;
SQL
)"

    printf '本次写入：%s 条\n' "$batch_size"
    printf '当前总数：%s 条\n' "$total_rows"
    printf '最早 create_time：%s\n' "$first_create_time"
    printf '最新 create_time：%s\n' "$last_create_time"
}

main "$@"
