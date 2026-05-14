#!/usr/bin/env bash
# /resource-memory-top [--threshold-mb N]
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THRESHOLD_MB=500
while [[ $# -gt 0 ]]; do
  case "$1" in --threshold-mb) THRESHOLD_MB="$2"; shift 2;; *) shift;; esac
done
command -v witr &>/dev/null || { echo '{"error":"witr not found"}' >&2; exit 1; }
PIDS=$(ps -axo pid=,rss= | awk -v t="$((THRESHOLD_MB*1024))" '$2>t{print $1}' | sort -n)
results="[]"
for pid in $PIDS; do
  RAW=$(witr "$pid" --verbose --json --warnings 2>/dev/null) || continue
  CLASSIFIED=$(echo "$RAW" | bash "${SKILL_DIR}/scripts/classify.sh") || continue
  entry=$(echo "$CLASSIFIED" | jq 'del(.raw)')
  results=$(echo "$results" | jq --argjson e "$entry" '. + [$e]')
done
results=$(echo "$results" | jq 'sort_by(-.rss_mb)')
count=$(echo "$results" | jq 'length')
inappropriate=$(echo "$results" | jq '[.[]|select(.drain_class=="inappropriate")]|length')
jq -n --argjson r "$results" --argjson c "$count" --argjson i "$inappropriate" --argjson t "$THRESHOLD_MB" \
  '{threshold_mb:$t,total:$c,inappropriate_count:$i,
    summary:"\($c) process(es) above \($t)MB RSS. \($i) inappropriate.",processes:$r}'
