#!/usr/bin/env bash
# /resource-fd-pressure
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THRESHOLD="${1:-0.4}"
command -v witr &>/dev/null || { echo '{"error":"witr not found"}' >&2; exit 1; }
ALL_PIDS=$(ps -axo pid= | tr -d ' ')
flagged="[]"
fd_limit=$(launchctl limit maxfiles 2>/dev/null | awk '{print $2}' | head -1)
fd_limit="${fd_limit:-256}"
for pid in $ALL_PIDS; do
  fd_count=$(lsof -p "$pid" 2>/dev/null | wc -l | tr -d ' ') || continue
  ratio=$(awk "BEGIN {if ($fd_limit>0) printf \"%.3f\",$fd_count/$fd_limit; else print 0}")
  awk "BEGIN {exit !($ratio > $THRESHOLD)}" || continue
  RAW=$(witr "$pid" --verbose --json --warnings 2>/dev/null) || continue
  CLASSIFIED=$(echo "$RAW" | bash "${SKILL_DIR}/scripts/classify.sh") || continue
  entry=$(echo "$CLASSIFIED" | jq \
    --argjson fc "$fd_count" --argjson fl "$fd_limit" --argjson r "$ratio" \
    '. + {fd_open:$fc,fd_limit:$fl,fd_ratio:$r} | del(.raw)')
  flagged=$(echo "$flagged" | jq --argjson e "$entry" '. + [$e]')
done
count=$(echo "$flagged" | jq 'length')
jq -n --argjson f "$flagged" --argjson c "$count" --arg t "$THRESHOLD" \
  '{threshold_ratio:($t|tonumber),flagged_count:$c,
    summary:"\($c) process(es) exceed FD threshold \($t).",processes:$f}'
