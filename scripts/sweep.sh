#!/usr/bin/env bash
# /resource-sweep — top 15 CPU consumers, classified and ranked
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOP_N="${1:-15}"
command -v witr &>/dev/null || { echo '{"error":"witr not found: brew install witr"}' >&2; exit 1; }
PIDS=$(ps -axo pid=,pcpu= | sort -rn -k2 | head -"$TOP_N" | awk '{print $1}')
results="[]"; rank=0
for pid in $PIDS; do
  rank=$((rank+1))
  RAW=$(witr "$pid" --verbose --json --warnings --env 2>/dev/null) || continue
  CLASSIFIED=$(echo "$RAW" | bash "${SKILL_DIR}/scripts/classify.sh") || continue
  entry=$(echo "$CLASSIFIED" | jq --argjson r "$rank" '. + {rank:$r} | del(.raw)')
  results=$(echo "$results" | jq --argjson e "$entry" '. + [$e]')
done
ic=$(echo "$results" | jq '[.[]|select(.drain_class=="inappropriate")]|length')
sc=$(echo "$results" | jq '[.[]|select(.drain_class=="suspicious")]|length')
jq -n --argjson r "$results" --argjson ic "$ic" --argjson sc "$sc" --argjson t "$rank" \
  '{sweep_total:$t,inappropriate_count:$ic,suspicious_count:$sc,
    summary:"Swept \($t) processes. Inappropriate: \($ic). Suspicious: \($sc).",processes:$r}'
