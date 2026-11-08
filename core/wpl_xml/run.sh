#!/usr/bin/env bash
set -euo pipefail

# Enter script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Verify commands exist
for cmd in wparse wpgen wpadm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: Command '$cmd' not found in PATH"
    exit 1
  fi
done

# Tunables
LINE_CNT=${LINE_CNT:-2000}
STAT_SEC=${STAT_SEC:-2}

# Prepare configuration and data
wpadm check || true
wpadm data clean || true
wpgen data clean || true
rm -rf .run

echo "1> gen sample data (4-line rotation: 2 JSON-with-XML + 2 raw XML)"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC"
test -s "./data/in_dat/gen.dat" || { echo "missing ./data/in_dat/gen.dat"; exit 1; }

echo "2> parse in batch"
if ! wparse batch --stat "$STAT_SEC" -p -n "$LINE_CNT"; then
  echo "wparse work failed. check ./data/logs/wparse.log and ./data/logs/wparse.stdout (if exists)."
  exit 1
fi

echo "3> validate outputs"
wpadm data stat
wpadm data validate

echo "4> spot-check parsed XML fields"
SANGFOR="./data/out_dat/sangfor_ips.dat"
ALERT="./data/out_dat/xml_alert.dat"
grep -q 'res_url: "172.16.8.248/\*\*\*\*/aa.php' "$SANGFOR" \
  || { echo "miss: res_url not extracted from JSON result"; exit 1; }
grep -q 'res_status_code: 302' "$SANGFOR" \
  || { echo "miss: res_status_code not extracted as int"; exit 1; }
grep -q 'res_url: "/login.php"' "$SANGFOR" \
  || { echo "miss: reordered/missing-field XML was not parsed"; exit 1; }
grep -q 'rule_name: "webshell_upload"' "$ALERT" \
  || { echo "miss: raw XML rule_name not extracted"; exit 1; }
grep -q 'rule_name: "sql_injection"' "$ALERT" \
  || { echo "miss: reordered raw XML was not parsed"; exit 1; }
if grep -q 'vxlan_vni_1' "$SANGFOR"; then
  echo "unexpected: _@vxlan_vni_1 should have been dropped"; exit 1
fi

echo
echo "pass: XML 元素按路径取值（与顺序无关、缺失跳过），JSON 内嵌 XML 也正常解析。"
