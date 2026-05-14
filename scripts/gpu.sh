#!/usr/bin/env bash
# /resource-gpu
set -euo pipefail
if [[ "$EUID" -ne 0 ]]; then
  THERM_RAW=$(pmset -g therm 2>/dev/null || echo "")
  CPU_LIMIT=$(echo "$THERM_RAW" | awk '/CPU_Speed_Limit/{print $3}' | head -1)
  CPU_LIMIT="${CPU_LIMIT:-100}"
  jq -n --arg n "sudo required for powermetrics" --argjson cl "$CPU_LIMIT" \
    '{gpu_available:false,note:$n,thermal_proxy:{cpu_speed_limit_pct:$cl,
      agent_signal:(if $cl<100 then "GPU/CPU thermal pressure: CPU capped at \($cl)%" else "No thermal throttling" end)}}'
  exit 0
fi
PM_RAW=$(powermetrics --samplers gpu_power -n1 -i500 2>/dev/null | head -40 || echo "")
gpu_active=$(echo "$PM_RAW"|grep -i "GPU Active Residency"|grep -oE '[0-9]+(\.[0-9]+)?%'|head -1|tr -d '%')
gpu_freq=$(echo "$PM_RAW"|grep -i "GPU Frequency"|grep -oE '[0-9]+'|head -1)
gpu_power=$(echo "$PM_RAW"|grep -i "GPU Power"|grep -oE '[0-9]+(\.[0-9]+)?'|head -1)
gpu_active="${gpu_active:-0}"; gpu_freq="${gpu_freq:-0}"; gpu_power="${gpu_power:-0}"
drain_class="appropriate"; signal="GPU utilisation within normal range"
awk "BEGIN {exit !($gpu_active > 80)}" && { drain_class="suspicious"; signal="GPU Active Residency ${gpu_active}% — high GPU load"; }
jq -n --arg a "$gpu_active" --arg f "$gpu_freq" --arg p "$gpu_power" \
  --arg dc "$drain_class" --arg s "$signal" \
  '{gpu_available:true,active_residency_pct:($a|tonumber),frequency_mhz:($f|tonumber),
    power_mw:($p|tonumber),drain_class:$dc,signal:$s}'
