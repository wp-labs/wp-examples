#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

REPO_URL="${REPO_URL:-https://github.com/wp-labs/editor-monitor-conf.git}"
INIT_VERSION="${INIT_VERSION:-0.1.4}"
TARGET_VERSION="${TARGET_VERSION:-0.1.5}"
REQUESTED_VERSION="${INIT_VERSION#v}"
REQUESTED_TARGET_VERSION="${TARGET_VERSION#v}"
WORK_ROOT="${WORK_ROOT:-$PWD/.tmp-work}"
REQUEST_ID="${REQUEST_ID:-core-remote-ctrl}"
RELOAD_TIMEOUT_MS="${RELOAD_TIMEOUT_MS:-1000}"
ADMIN_BIND="${ADMIN_BIND:-127.0.0.1:19090}"

for cmd in wparse wproj; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: command '$cmd' not found in PATH"
    exit 1
  fi
done

cleanup() {
  if [[ -n "${WPARSE_PID:-}" ]] && kill -0 "$WPARSE_PID" >/dev/null 2>&1; then
    kill "$WPARSE_PID" >/dev/null 2>&1 || true
    wait "$WPARSE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "1> prepare work root"
rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

echo "2> remote init from $REPO_URL @ $REQUESTED_VERSION"
wproj init --work-root "$WORK_ROOT" --repo "$REPO_URL" --version "$REQUESTED_VERSION"

STATE_FILE="$WORK_ROOT/.run/project_remote_state.json"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: remote init did not materialize .run/project_remote_state.json"
  exit 1
fi

if ! grep -Eq "\"current_version\"[[:space:]]*:[[:space:]]*\"$REQUESTED_VERSION\"" "$STATE_FILE"; then
  echo "Error: unexpected initialized project version"
  cat "$STATE_FILE"
  exit 1
fi

echo "3> prepare admin token under \$HOME"
mkdir -p "${HOME}/.warp_parse"
printf 'test-token\n' > "${HOME}/.warp_parse/admin_api.token"
chmod 600 "${HOME}/.warp_parse/admin_api.token"

mkdir -p "$WORK_ROOT/data/in_dat"
if [[ -f "$WORK_ROOT/models/wpl/sample.dat" ]]; then
  cp "$WORK_ROOT/models/wpl/sample.dat" "$WORK_ROOT/data/in_dat/gen.dat"
else
  printf '\n' > "$WORK_ROOT/data/in_dat/gen.dat"
fi

echo "4> start daemon"
wparse daemon --work-root "$WORK_ROOT" >/dev/null 2>&1 &
WPARSE_PID=$!

echo "5> wait for admin status"
STATUS_JSON=""
for _ in $(seq 1 80); do
  STATUS_JSON="$(wproj engine status --work-root "$WORK_ROOT" --json 2>/dev/null || true)"
  if printf '%s' "$STATUS_JSON" | grep -Eq '"accepting_commands"[[:space:]]*:[[:space:]]*true'; then
    break
  fi
  sleep 0.25
done

if ! printf '%s' "$STATUS_JSON" | grep -Eq '"accepting_commands"[[:space:]]*:[[:space:]]*true'; then
  echo "Error: admin API did not become ready"
  echo "Expected bind: $ADMIN_BIND"
  if [[ -f "$WORK_ROOT/data/logs/wparse.log" ]]; then
    echo "--- wparse.log ---"
    tail -n 120 "$WORK_ROOT/data/logs/wparse.log" || true
  fi
  exit 1
fi

if ! printf '%s' "$STATUS_JSON" | grep -Eq "\"project_version\"[[:space:]]*:[[:space:]]*\"$REQUESTED_VERSION\""; then
  echo "Error: runtime status does not report expected project_version"
  echo "$STATUS_JSON"
  exit 1
fi

echo "6> trigger admin reload with remote update to $REQUESTED_TARGET_VERSION"
RELOAD_JSON="$(wproj engine reload --work-root "$WORK_ROOT" --request-id "$REQUEST_ID" --update --version "$REQUESTED_TARGET_VERSION" --timeout-ms "$RELOAD_TIMEOUT_MS" --json)"
echo "$RELOAD_JSON"

if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"accepted"[[:space:]]*:[[:space:]]*true'; then
  echo "Error: reload response is not accepted"
  exit 1
fi

if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"update"[[:space:]]*:[[:space:]]*true'; then
  echo "Error: reload response did not enable update"
  exit 1
fi

if ! printf '%s' "$RELOAD_JSON" | grep -Eq "\"requested_version\"[[:space:]]*:[[:space:]]*\"$REQUESTED_TARGET_VERSION\""; then
  echo "Error: reload response does not report expected requested_version"
  exit 1
fi

if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"result"[[:space:]]*:[[:space:]]*"(reload_done|running)"'; then
  echo "Error: reload response is neither reload_done nor running"
  exit 1
fi

echo "7> verify runtime status after reload"
STATUS_AFTER=""
for _ in $(seq 1 60); do
  STATUS_AFTER="$(wproj engine status --work-root "$WORK_ROOT" --json 2>/dev/null || true)"
  if printf '%s' "$STATUS_AFTER" | grep -Eq "\"last_reload_request_id\"[[:space:]]*:[[:space:]]*\"$REQUEST_ID\"" \
    && printf '%s' "$STATUS_AFTER" | grep -Eq '"reloading"[[:space:]]*:[[:space:]]*false'; then
    break
  fi
  sleep 0.25
done

echo "$STATUS_AFTER"

if ! printf '%s' "$STATUS_AFTER" | grep -Eq "\"last_reload_request_id\"[[:space:]]*:[[:space:]]*\"$REQUEST_ID\""; then
  echo "Error: runtime status did not record the expected reload request id"
  exit 1
fi

if ! printf '%s' "$STATUS_AFTER" | grep -Eq '"last_reload_result"[[:space:]]*:[[:space:]]*"reload_done"'; then
  echo "Error: runtime status did not record reload_done"
  exit 1
fi

if ! printf '%s' "$STATUS_AFTER" | grep -Eq "\"project_version\"[[:space:]]*:[[:space:]]*\"$REQUESTED_TARGET_VERSION\""; then
  echo "Error: runtime status did not switch project_version to $REQUESTED_TARGET_VERSION"
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: project remote state file disappeared after reload update"
  exit 1
fi

if ! grep -Eq "\"current_version\"[[:space:]]*:[[:space:]]*\"$REQUESTED_TARGET_VERSION\"" "$STATE_FILE"; then
  echo "Error: project remote state was not updated to $REQUESTED_TARGET_VERSION"
  cat "$STATE_FILE"
  exit 1
fi

echo "PASS: remote init + admin reload update to $REQUESTED_TARGET_VERSION"
