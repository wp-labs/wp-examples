#!/usr/bin/env bash
set -euo pipefail

# 创建 HTTP 请求日志达梦表。
# 说明：
# 1. 优先使用 ODBC `isql` 执行 SQL，不再依赖 Python 的 dmPython 驱动。
# 2. `DM_DSN` 仅支持 ODBC DSN 名称或 ODBC 连接串；不再支持 dmPython 风格的 `user/password@host:port`。

TABLE_NAME="http_request_logs"
TABLE_NAME_COPY="http_request_logs_copy"
DEFAULT_SERVER="127.0.0.1"
DEFAULT_PORT="5236"
DEFAULT_USER="SYSDBA"
DEFAULT_PASSWORD="SYSDBA"

DM_USER="${DMUSER:-$DEFAULT_USER}"
DM_PASSWORD="${DMPASSWORD:-$DEFAULT_PASSWORD}"
DM_SERVER="${DMSERVER:-$DEFAULT_SERVER}"
DM_PORT="${DMPORT:-$DEFAULT_PORT}"
DM_DSN_VALUE="${DM_DSN:-}"
SCHEMA_NAME="$(printf '%s' "${DMSCHEMA:-$DM_USER}" | tr '[:lower:]' '[:upper:]')"

log() {
    printf '%s\n' "$*"
}

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

qualified_table_name() {
    printf '%s.%s\n' "$SCHEMA_NAME" "$1"
}

table_key() {
    printf '%s' "$1" | awk -F. '{print toupper($NF)}'
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

run_sql_text() {
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
    if [[ -n "$output" ]]; then
        printf '%s\n' "$output"
    fi
}

query_scalar() {
    local output

    output="$(run_sql_text <<SQL
SELECT COUNT(*) FROM $1;
SQL
)"

    printf '%s\n' "$output" | awk '
        {
            line = $0
            gsub(/^[[:space:]\|]+/, "", line)
            gsub(/[[:space:]\|]+$/, "", line)
            if (line ~ /^[0-9]+$/) {
                print line
                exit
            }
        }
    '
}

create_table_if_needed() {
    local base_table_name="$1"
    local qualified_name
    local key
    local index_name
    local table_name_upper
    local table_count
    local index_count

    qualified_name="$(qualified_table_name "$base_table_name")"
    key="$(table_key "$qualified_name")"
    index_name="IDX_${key}_CREATE_TIME"
    table_name_upper="$(printf '%s' "$base_table_name" | tr '[:lower:]' '[:upper:]')"

    table_count="$(query_scalar "ALL_TABLES WHERE OWNER = '${SCHEMA_NAME}' AND TABLE_NAME = '${table_name_upper}'")"
    if [[ "$table_count" == "0" ]]; then
        run_sql_text <<SQL
CREATE TABLE $qualified_name ("id" BIGINT IDENTITY(1,1) PRIMARY KEY, "sip" VARCHAR(64) NOT NULL, "timestamp" TIMESTAMP(6) WITH TIME ZONE NOT NULL, "http/request" CLOB NOT NULL, "status" INT NOT NULL, "create_time" TIMESTAMP(6) WITH TIME ZONE NOT NULL, "update_time" TIMESTAMP(6) WITH TIME ZONE NOT NULL, CONSTRAINT ${key}_CREATE_TIME_UK UNIQUE ("create_time"), CONSTRAINT ${key}_UPDATE_TIME_CK CHECK ("update_time" >= "create_time"));
SQL
        log "已创建表：$qualified_name"
    else
        log "已确认表存在：$qualified_name"
    fi

    index_count="$(query_scalar "ALL_INDEXES WHERE OWNER = '${SCHEMA_NAME}' AND INDEX_NAME = '${index_name}'")"
    if [[ "$index_count" == "0" ]]; then
        run_sql_text <<SQL
CREATE INDEX $index_name ON $qualified_name ("create_time");
SQL
        log "已创建索引：$index_name"
    else
        log "已确认索引存在：$index_name"
    fi

    run_sql_text <<SQL
COMMENT ON TABLE $qualified_name IS 'HTTP 请求日志测试表';
COMMENT ON COLUMN $qualified_name."id" IS '自增主键';
COMMENT ON COLUMN $qualified_name."sip" IS '源 IP 地址';
COMMENT ON COLUMN $qualified_name."timestamp" IS '请求发生时间';
COMMENT ON COLUMN $qualified_name."http/request" IS 'HTTP 请求行';
COMMENT ON COLUMN $qualified_name."status" IS 'HTTP 响应状态码';
COMMENT ON COLUMN $qualified_name."create_time" IS '创建时间，TIMESTAMP WITH TIME ZONE 类型，插入脚本按当前最大值递增生成';
COMMENT ON COLUMN $qualified_name."update_time" IS '更新时间，TIMESTAMP WITH TIME ZONE 类型';
SQL
}

main() {
    validate_identifier "$SCHEMA_NAME"
    create_table_if_needed "$TABLE_NAME"
    create_table_if_needed "$TABLE_NAME_COPY"
}

main "$@"
