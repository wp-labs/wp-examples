#!/usr/bin/env bash
set -euo pipefail

# 进入脚本所在目录
cd "$(dirname "${BASH_SOURCE[0]}")"

LINE_CNT=${LINE_CNT:-300}
STAT_SEC=${STAT_SEC:-1}
OUT_DIR="./data/out_dat"

die() {
    echo "FAIL: $*" >&2
    exit 1
}

line_count() { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
gz_lines()   { gunzip -c "$1" | wc -l | tr -d ' '; }
zip_lines()  { unzip -p "$1" | wc -l | tr -d ' '; }

for cmd in wparse wpgen wpadm unzip gunzip; do
    command -v "$cmd" >/dev/null || { echo "Error: $cmd not found in PATH" >&2; exit 1; }
done

echo "1> init conf & data"
rm -f ./wparse.local.toml
wpadm check
wpadm data clean || true
wpgen data clean || true
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "2> gen sample data (${LINE_CNT} lines)"
wpgen sample -n "$LINE_CNT" --stat "$STAT_SEC" -p
INPUT=$(line_count ./data/in_dat/gen.dat)
[ "$INPUT" -gt 0 ] || die "no input generated (./data/in_dat/gen.dat is empty)"

echo "3> run wparse batch"
wparse batch --stat "$STAT_SEC" -p -n "$INPUT"

# ---------------------------------------------------------------- 断言
FLAT="$OUT_DIR/roll_flat.dat"
ZIP_ACTIVE="$OUT_DIR/roll_zip.dat"
GZ_ACTIVE="$OUT_DIR/roll_gz.dat"

echo "4> control: no max_size => never rolls"
[ -f "$FLAT" ] || die "missing $FLAT"
[ "$(line_count "$FLAT")" -eq "$INPUT" ] \
    || die "flat sink lines=$(line_count "$FLAT") != input=$INPUT"
for f in "$FLAT".*; do
    [ -e "$f" ] && die "flat sink must not roll, found: $f"
done
[ "$(head -c 1 "$FLAT")" = "{" ] || die "flat sink output is not JSON: $FLAT"

echo "5> zip archives: keep all records (max_rolls=100)"
[ -f "$ZIP_ACTIVE" ] || die "missing $ZIP_ACTIVE"
[ -f "$ZIP_ACTIVE.1.zip" ] || die "missing first zip archive $ZIP_ACTIVE.1.zip"
ZIP_ARCHIVES=0
ZIP_TOTAL=$(line_count "$ZIP_ACTIVE")
for f in "$ZIP_ACTIVE".*.zip; do
    [ -e "$f" ] || continue
    ZIP_ARCHIVES=$((ZIP_ARCHIVES + 1))
    unzip -tq "$f" >/dev/null || die "corrupt zip archive: $f"
    entries=$(unzip -Z1 "$f" | wc -l | tr -d ' ')
    [ "$entries" -eq 1 ] || die "zip archive should hold exactly 1 entry, got $entries: $f"
    n=$(zip_lines "$f")
    [ "$n" -gt 0 ] || die "empty zip archive: $f"
    ZIP_TOTAL=$((ZIP_TOTAL + n))
done
[ "$ZIP_ARCHIVES" -ge 2 ] || die "expected >=2 zip archives, got $ZIP_ARCHIVES"
[ "$ZIP_TOTAL" -eq "$INPUT" ] \
    || die "zip total lines=$ZIP_TOTAL != input=$INPUT (records lost or duplicated)"

echo "6> gzip archives: retention bound (max_rolls=2)"
[ -f "$GZ_ACTIVE" ] || die "missing $GZ_ACTIVE"
[ -f "$GZ_ACTIVE.1.gz" ] || die "missing $GZ_ACTIVE.1.gz"
[ -f "$GZ_ACTIVE.2.gz" ] || die "missing $GZ_ACTIVE.2.gz"
[ ! -e "$GZ_ACTIVE.3.gz" ] || die "max_rolls=2 must delete $GZ_ACTIVE.3.gz"
GZ1=$(gz_lines "$GZ_ACTIVE.1.gz")
GZ2=$(gz_lines "$GZ_ACTIVE.2.gz")
GZ_ACTIVE_LINES=$(line_count "$GZ_ACTIVE")
[ "$GZ1" -gt 0 ] || die "empty archive: $GZ_ACTIVE.1.gz"
[ "$GZ2" -gt 0 ] || die "empty archive: $GZ_ACTIVE.2.gz"
GZ_TOTAL=$((GZ_ACTIVE_LINES + GZ1 + GZ2))
[ "$GZ_TOTAL" -lt "$INPUT" ] \
    || die "max_rolls=2 should drop oldest records (kept=$GZ_TOTAL input=$INPUT)"

echo
echo "PASS: file sink rolling + archive compression verified"
echo "  input lines : $INPUT"
echo "  zip         : active=$(line_count "$ZIP_ACTIVE") + archives=$ZIP_ARCHIVES => $ZIP_TOTAL lines (no loss)"
echo "  gzip        : active=$GZ_ACTIVE_LINES + .1.gz=$GZ1 + .2.gz=$GZ2 (oldest dropped)"
echo "  flat        : $(line_count "$FLAT") lines, no archives"
