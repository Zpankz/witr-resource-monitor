#!/usr/bin/env bash
# /resource-agent-context — consolidated LLM-ready JSON blob
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
echo "Gathering thermal..." >&2
THERMAL=$(bash "${SKILL_DIR}/scripts/thermal.sh" 2>/dev/null) || THERMAL='{"error":"unavailable"}'
echo "Sweeping CPU..." >&2
SWEEP=$(bash "${SKILL_DIR}/scripts/sweep.sh" 2>/dev/null) || SWEEP='{"error":"unavailable"}'
echo "Gathering RAM..." >&2
MEM=$(bash "${SKILL_DIR}/scripts/memory-top.sh" --threshold-mb 300 2>/dev/null) || MEM='{"error":"unavailable"}'
TOP_CPU=$(echo "$SWEEP" | jq '.processes[:5]|map({rank,pid,command,cpu_pct,rss_mb,drain_class,signals})//[]')
TOP_MEM=$(echo "$MEM"   | jq '.processes[:5]|map({pid,command,cpu_pct,rss_mb,drain_class,signals})//[]')
INAPP=$(echo "$SWEEP" | jq '[.processes[]|select(.drain_class=="inappropriate")]|map({pid,command,cpu_pct,rss_mb,source_type,thermal_state,signals})')
SUSP=$(echo "$SWEEP"  | jq '[.processes[]|select(.drain_class=="suspicious")]|map({pid,command,cpu_pct,rss_mb,source_type,signals})')
TL=$(echo "$THERMAL" | jq -r '.thermal_level//"unknown"')
SB=$(echo "$THERMAL" | jq '.prevents_sleep_count//0')
IC=$(echo "$INAPP" | jq 'length')
SC=$(echo "$SUSP"  | jq 'length')
SUMMARY="Thermal: ${TL}. Sleep blockers: ${SB}. Inappropriate: ${IC}. Suspicious: ${SC}."
jq -n \
  --arg ts "$TIMESTAMP" --argjson th "$THERMAL" \
  --argjson tc "$TOP_CPU" --argjson tm "$TOP_MEM" \
  --argjson ia "$INAPP" --argjson su "$SUSP" --arg sm "$SUMMARY" \
  '{timestamp:$ts,thermal:$th,top_cpu_consumers:$tc,top_mem_consumers:$tm,
    inappropriate_drains:$ia,suspicious_processes:$su,summary:$sm,
    agent_instructions:"Review inappropriate_drains first. signals[] explains each classification. Use /resource-inspect <pid> for deeper analysis."}'
