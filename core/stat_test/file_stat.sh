#!/usr/bin/env sh
set -eu

FILE="${1:-data/out_dat/monitor.dat}"

if [ ! -f "$FILE" ]; then
  echo "file not found: $FILE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found in PATH" >&2
  exit 1
fi

jq -n -r '
  def key($s; $t): "\($s)\u0000\($t)";
  reduce inputs as $i (
    {};
    if ($i.stage and $i.target
        and ($i.total | type == "number")
        and ($i.success | type == "number")) then
      (key($i.stage; $i.target)) as $k
      | .[$k].stage = $i.stage
      | .[$k].target = $i.target
      | .[$k].total = (.[$k].total // 0) + $i.total
      | .[$k].success = (.[$k].success // 0) + $i.success
    else .
    end
  )
  | "stage\ttarget\ttotal\tsuccess",
    (to_entries
     | sort_by(.value.stage, .value.target)
     | .[]
     | [.value.stage, .value.target, (.value.total|tostring), (.value.success|tostring)]
     | @tsv)
' "$FILE"
