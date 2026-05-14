#!/usr/bin/env bash
# /resource-thermal
set -euo pipefail
THERM_RAW=$(pmset -g therm 2>/dev/null || echo "")
CPU_LIMIT=100; THERMAL_LEVEL="Normal"
if [[ -n "$THERM_RAW" ]]; then
  CPU_LIMIT=$(echo "$THERM_RAW" | awk '/CPU_Speed_Limit/{print $3}' | head -1)
  CPU_LIMIT="${CPU_LIMIT:-100}"
  if   (( $(echo "$CPU_LIMIT < 50"  | bc -l) )); then THERMAL_LEVEL="Heavy throttling"
  elif (( $(echo "$CPU_LIMIT < 80"  | bc -l) )); then THERMAL_LEVEL="Moderate throttling"
  elif (( $(echo "$CPU_LIMIT < 100" | bc -l) )); then THERMAL_LEVEL="Light throttling"
  fi
fi
ASSERT_RAW=$(pmset -g assertions 2>/dev/null || echo "")
SLEEP_BLOCKERS="[]"
[[ -n "$ASSERT_RAW" ]] && SLEEP_BLOCKERS=$(echo "$ASSERT_RAW" \
  | grep -A100 'PreventUserIdleSystemSleep\|PreventSystemSleep' \
  | grep -oE '\(pid [0-9]+\).*' | jq -R . | jq -s . 2>/dev/null || echo "[]")
sleep_count=$(echo "$SLEEP_BLOCKERS" | jq 'length')
BATTERY_PCT="?"; BATTERY_CHARGING="unknown"; BATTERY_STATE="unknown"
IOREG_RAW=$(ioreg -rc IOPMPowerSource 2>/dev/null | head -50 || echo "")
if [[ -n "$IOREG_RAW" ]]; then
  BATTERY_PCT=$(echo "$IOREG_RAW" | grep -o '"CurrentCapacity" = [0-9]*' | awk '{print $3}' | head -1)
  IS_CHARGING=$(echo "$IOREG_RAW" | grep -o '"IsCharging" = [A-Za-z]*' | awk '{print $3}' | head -1)
  BATTERY_CHARGING="${IS_CHARGING:-unknown}"; BATTERY_STATE="detected"
fi
jq -n \
  --arg tl "$THERMAL_LEVEL" --argjson cl "$CPU_LIMIT" \
  --argjson sc "$sleep_count" --argjson sb "$SLEEP_BLOCKERS" \
  --arg bp "${BATTERY_PCT:-?}" --arg bc "$BATTERY_CHARGING" --arg bs "$BATTERY_STATE" \
  '{thermal_level:$tl,cpu_speed_limit_pct:$cl,prevents_sleep_count:$sc,
    sleep_blocker_details:$sb,
    battery:{state:$bs,charge_pct:$bp,is_charging:$bc},
    agent_signal:(if $tl!="Normal" then "WARN Thermal: \($tl) — CPU capped at \($cl)%" else "OK Thermal: Normal" end)}'
