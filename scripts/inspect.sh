#!/usr/bin/env bash
# /resource-inspect <name_or_pid>
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"
[[ -z "$TARGET" ]] && { echo '{"error":"Usage: inspect.sh <name_or_pid>"}' >&2; exit 1; }
command -v witr &>/dev/null || { echo '{"error":"witr not found: brew install witr"}' >&2; exit 1; }
RAW=$(witr "$TARGET" --verbose --json --warnings --env 2>/dev/null) || { echo '{"error":"witr failed"}' >&2; exit 1; }
CLASSIFIED=$(echo "$RAW" | bash "${SKILL_DIR}/scripts/classify.sh")
drain_class=$(echo "$CLASSIFIED" | jq -r '.drain_class')
score=$(echo "$CLASSIFIED" | jq -r '.score')
cmd=$(echo "$CLASSIFIED" | jq -r '.command')
cpu=$(echo "$CLASSIFIED" | jq -r '.cpu_pct')
rss=$(echo "$CLASSIFIED" | jq -r '.rss_mb')
thermal=$(echo "$CLASSIFIED" | jq -r '.thermal_state')
summary="[${drain_class^^}] ${cmd} | CPU=${cpu}% RAM=${rss}MB Thermal=${thermal} Score=${score}/100"
echo "$CLASSIFIED" | jq --arg s "$summary" '. + {summary:$s}'
