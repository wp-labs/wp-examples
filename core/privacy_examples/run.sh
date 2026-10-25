#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

# 可调参数：生成/采集规模与统计间隔
LINE_CNT=${LINE_CNT:-100}
STAT_SEC=${STAT_SEC:-2}
GEN_STAT_SEC=${GEN_STAT_SEC:-3}

for cmd in wparse wpgen wpadm openssl; do
    if ! command -v "$cmd" >/dev/null; then
        echo "Error: $cmd not found in PATH"
        exit 1
    fi
done

echo "1> prepare test secrets (.warp_parse/sec_key.toml)"
mkdir -p .warp_parse
if [ ! -f .warp_parse/sec_key.toml ]; then
    umask 077
    cat > .warp_parse/sec_key.toml <<SECRETS
sec_pii_salt = "$(openssl rand -base64 32)"
sec_pii_key  = "$(openssl rand -base64 32)"
SECRETS
    chmod 600 .warp_parse/sec_key.toml
    echo "   generated example-only secrets (never reuse in production)"
else
    echo "   reusing existing .warp_parse/sec_key.toml"
fi

echo "2> check conf & clean data"
wpadm check
wpadm data clean || true
wpgen data clean || true

echo "3> gen sample data"
wpgen sample -n "$LINE_CNT" --stat "$GEN_STAT_SEC"

echo "4> run wparse batch"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
    echo "wparse work failed. check ./data/logs/wparse.log"
    exit 1
fi

echo "5> validate output"
wpadm data stat
wpadm data validate --input-cnt "$LINE_CNT"

echo "6> verify privacy invariants"
if command -v python3 >/dev/null; then
python3 - <<'PY'
import ipaddress
import json

path = "data/out_dat/privacy_mask.json"

def first_octet_ok(ip):
    return int(str(ip).split(".")[0]) >= 240

count = 0
with open(path, encoding="utf-8") as fh:
    for line in fh:
        if not line.strip():
            continue
        rec = json.loads(line)
        assert "notes" not in rec, "remove must drop notes"
        assert rec["mobile"].startswith("*"), rec["mobile"]
        assert "***" in rec["mail"], rec["mail"]
        assert len(rec["uid_hash"]) == 64, rec["uid_hash"]
        assert rec["uid_token"].startswith("tok:v1:"), rec["uid_token"]
        assert "***" in rec["backup_mail"], rec["backup_mail"]
        assert rec["summary"]["mail"] == rec["mail"]
        assert rec["summary"]["s_ip"] == rec["s_ip"]
        for key in ("s_ip", "d_ip"):
            ip = ipaddress.ip_address(rec[key])
            if ip.version == 4:
                assert first_octet_ok(ip), rec[key]
            else:
                assert str(ip).startswith("2001:db8:"), rec[key]
        count += 1

assert count > 0, "no records produced"
print(f"privacy invariants: {count} records OK")
PY
else
    echo "python3 not found; skipping invariant checks"
fi

echo "7> sample output (privacy_mask.json)"
head -n 2 data/out_dat/privacy_mask.json || true
