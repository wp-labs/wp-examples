#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

MODELS_REPO_URL="${MODELS_REPO_URL:-https://github.com/wp-labs/wp-rule.git}"
INFRA_REPO_URL="${INFRA_REPO_URL:-https://github.com/wp-labs/editor-monitor-conf.git}"
MODELS_INIT_VERSION="${MODELS_INIT_VERSION:-0.1.0}"
INFRA_INIT_VERSION="${INFRA_INIT_VERSION:-0.1.6}"
MODELS_TARGET_VERSION="${MODELS_TARGET_VERSION:-0.1.1}"
INFRA_TARGET_VERSION="${INFRA_TARGET_VERSION:-0.1.7}"
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

echo "2> write bootstrap config (only project_remote section)"
mkdir -p "$WORK_ROOT/conf"
cat > "$WORK_ROOT/conf/wparse.toml" <<EOF
[project_remote]
enabled = true
repo = ""

[project_remote.models]
repo = "${MODELS_REPO_URL}"
init_version = "${MODELS_INIT_VERSION}"

[project_remote.infra]
repo = "${INFRA_REPO_URL}"
init_version = "${INFRA_INIT_VERSION}"
EOF

echo "3> sync infra from $INFRA_REPO_URL (brings conf/, topology/, connectors/)"
wproj conf update --work-root "$WORK_ROOT" --group infra --version "$INFRA_INIT_VERSION"

# Verify infra directories are populated
if [[ ! -f "$WORK_ROOT/conf/wparse.toml" ]]; then
  echo "Error: infra sync did not create conf/wparse.toml"
  exit 1
fi
if ! grep -q '\[models\]' "$WORK_ROOT/conf/wparse.toml"; then
  echo "Error: conf/wparse.toml is not a full config after infra sync (missing [models])"
  exit 1
fi
if [[ ! -d "$WORK_ROOT/topology/sources" ]]; then
  echo "Error: infra sync did not create topology/sources/"
  exit 1
fi
if [[ ! -d "$WORK_ROOT/connectors" ]]; then
  echo "Error: infra sync did not create connectors/"
  exit 1
fi
echo "   infra dirs verified: conf/, topology/, connectors/ present"

echo "4> sync models from $MODELS_REPO_URL (brings models/)"
wproj conf update --work-root "$WORK_ROOT" --group models --version "$MODELS_INIT_VERSION"

# Verify models directory is populated
if [[ ! -d "$WORK_ROOT/models/wpl" ]]; then
  echo "Error: models sync did not create models/wpl/"
  exit 1
fi
if ! find "$WORK_ROOT/models/wpl" -name '*.wpl' 2>/dev/null | grep -q .; then
  echo "Error: models/wpl/ has no .wpl files after models sync"
  exit 1
fi
echo "   models dirs verified: models/wpl/ with .wpl files present"

echo "5> verify dual-repo state file"
STATE_FILE="$WORK_ROOT/.run/project_remote_state.json"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: sync did not materialize .run/project_remote_state.json"
  exit 1
fi
if ! grep -Eq '"models"[[:space:]]*:' "$STATE_FILE"; then
  echo "Error: state file does not contain dual-repo (models key)"
  cat "$STATE_FILE"
  exit 1
fi
if ! grep -Eq '"infra"[[:space:]]*:' "$STATE_FILE"; then
  echo "Error: state file does not contain dual-repo (infra key)"
  cat "$STATE_FILE"
  exit 1
fi
echo "   state file: dual-repo format verified"
echo "   $(cat "$STATE_FILE")"

echo "6> prepare admin token and sample data"
mkdir -p "${HOME}/.warp_parse"
printf 'test-token\n' > "${HOME}/.warp_parse/admin_api.token"
chmod 600 "${HOME}/.warp_parse/admin_api.token"

mkdir -p "$WORK_ROOT/data/in_dat"
SAMPLE_DAT="$(find "$WORK_ROOT/models/wpl" -name 'sample.dat' 2>/dev/null | head -1)"
if [[ -n "${SAMPLE_DAT:-}" ]]; then
  cp "$SAMPLE_DAT" "$WORK_ROOT/data/in_dat/gen.dat"
else
  printf '\n' > "$WORK_ROOT/data/in_dat/gen.dat"
fi

echo "7> start daemon"
wparse daemon --work-root "$WORK_ROOT" >/dev/null 2>&1 &
WPARSE_PID=$!

echo "8> wait for admin status"
STATUS_JSON=""
for _ in $(seq 1 80); do
  STATUS_JSON="$(wproj engine status --work-root "$WORK_ROOT" --json 2>/dev/null || true)"
  if printf '%s' "$STATUS_JSON" | grep -Eq '"accepting_commands"[[:space:]]*:[[:space:]]*true'; then
    break
  fi
  sleep 0.25
done
if ! printf '%s' "$STATUS_JSON" | grep -Eq '"accepting_commands"[[:space:]]*:[[:space:]]*true'; then
  echo "Error: admin API did not become ready (expected bind: $ADMIN_BIND)"
  if [[ -f "$WORK_ROOT/data/logs/wparse.log" ]]; then
    echo "--- wparse.log ---"
    tail -n 120 "$WORK_ROOT/data/logs/wparse.log" || true
  fi
  exit 1
fi
echo "$STATUS_JSON"

echo "9> trigger admin reload with models update to $MODELS_TARGET_VERSION"
RELOAD_JSON="$(wproj engine reload \
  --work-root "$WORK_ROOT" \
  --request-id "$REQUEST_ID" \
  --update \
  --group models \
  --version "$MODELS_TARGET_VERSION" \
  --timeout-ms "$RELOAD_TIMEOUT_MS" \
  --json)"
echo "$RELOAD_JSON"

if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"accepted"[[:space:]]*:[[:space:]]*true'; then
  echo "Error: reload response is not accepted"
  exit 1
fi
if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"update"[[:space:]]*:[[:space:]]*true'; then
  echo "Error: reload response did not enable update"
  exit 1
fi
if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"group"[[:space:]]*:[[:space:]]*"models"'; then
  echo "Error: reload response does not report group=models"
  exit 1
fi
if ! printf '%s' "$RELOAD_JSON" | grep -Eq "\"requested_version\"[[:space:]]*:[[:space:]]*\"$MODELS_TARGET_VERSION\""; then
  echo "Error: reload response does not report expected requested_version"
  exit 1
fi
if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"result"[[:space:]]*:[[:space:]]*"(reload_done|running)"'; then
  echo "Error: reload response is neither reload_done nor running"
  exit 1
fi

echo "10> verify runtime status after models reload"
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

echo "11> verify state file updated for models group"
if ! grep -Eq "\"version\"[[:space:]]*:[[:space:]]*\"$MODELS_TARGET_VERSION\"" "$STATE_FILE"; then
  echo "Error: project remote state was not updated to $MODELS_TARGET_VERSION"
  cat "$STATE_FILE"
  exit 1
fi
echo "   models version updated to $MODELS_TARGET_VERSION"

echo "12> trigger admin reload with infra update to $INFRA_TARGET_VERSION"
INFRA_REQUEST_ID="${REQUEST_ID}-infra"
RELOAD_JSON="$(wproj engine reload \
  --work-root "$WORK_ROOT" \
  --request-id "$INFRA_REQUEST_ID" \
  --update \
  --group infra \
  --version "$INFRA_TARGET_VERSION" \
  --timeout-ms "$RELOAD_TIMEOUT_MS" \
  --json)"
echo "$RELOAD_JSON"

if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"accepted"[[:space:]]*:[[:space:]]*true'; then
  echo "Error: infra reload response is not accepted"
  exit 1
fi
if ! printf '%s' "$RELOAD_JSON" | grep -Eq '"group"[[:space:]]*:[[:space:]]*"infra"'; then
  echo "Error: infra reload response does not report group=infra"
  exit 1
fi
if ! printf '%s' "$RELOAD_JSON" | grep -Eq "\"requested_version\"[[:space:]]*:[[:space:]]*\"$INFRA_TARGET_VERSION\""; then
  echo "Error: infra reload response does not report expected requested_version"
  exit 1
fi

echo "13> verify runtime status after infra reload"
STATUS_AFTER=""
for _ in $(seq 1 60); do
  STATUS_AFTER="$(wproj engine status --work-root "$WORK_ROOT" --json 2>/dev/null || true)"
  if printf '%s' "$STATUS_AFTER" | grep -Eq "\"last_reload_request_id\"[[:space:]]*:[[:space:]]*\"$INFRA_REQUEST_ID\"" \
    && printf '%s' "$STATUS_AFTER" | grep -Eq '"reloading"[[:space:]]*:[[:space:]]*false'; then
    break
  fi
  sleep 0.25
done
echo "$STATUS_AFTER"

if ! printf '%s' "$STATUS_AFTER" | grep -Eq "\"last_reload_request_id\"[[:space:]]*:[[:space:]]*\"$INFRA_REQUEST_ID\""; then
  echo "Error: runtime status did not record the infra reload request id"
  exit 1
fi
if ! printf '%s' "$STATUS_AFTER" | grep -Eq '"last_reload_result"[[:space:]]*:[[:space:]]*"reload_done"'; then
  echo "Error: runtime status did not record reload_done for infra reload"
  exit 1
fi

echo "14> verify state file updated for infra group"
if ! grep -Eq "\"version\"[[:space:]]*:[[:space:]]*\"$INFRA_TARGET_VERSION\"" "$STATE_FILE"; then
  echo "Error: project remote state was not updated to $INFRA_TARGET_VERSION for infra"
  cat "$STATE_FILE"
  exit 1
fi
echo "   infra version updated to $INFRA_TARGET_VERSION"
echo "   final state: $(cat "$STATE_FILE")"

echo "PASS: dual-repo models($MODELS_INIT_VERSION->$MODELS_TARGET_VERSION) + infra($INFRA_INIT_VERSION->$INFRA_TARGET_VERSION)"
