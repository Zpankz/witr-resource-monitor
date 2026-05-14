#!/usr/bin/env bash
# classify.sh — pure-function classifier
# Usage: witr <proc> --verbose --json --warnings --env | bash classify.sh

set -euo pipefail

WITR_JSON=$(cat)
drain_class="appropriate"
score=0
signals=()

pid=$(echo "$WITR_JSON"        | jq -r '.process.pid // "?"')
cmd=$(echo "$WITR_JSON"        | jq -r '.process.command // "unknown"')
cpu=$(echo "$WITR_JSON"        | jq -r '.process.cpu_percent // 0')
rss_bytes=$(echo "$WITR_JSON"  | jq -r '.process.memory_rss // 0')
rss_mb=$(echo "$rss_bytes"     | awk '{printf "%.1f", $1/1048576}')
health=$(echo "$WITR_JSON"     | jq -r '.process.health // ""')
source_type=$(echo "$WITR_JSON"| jq -r '.source.type // "unknown"')
service=$(echo "$WITR_JSON"    | jq -r '.process.service // ""')
exe_deleted=$(echo "$WITR_JSON"| jq -r '.process.exe_deleted // false')
thermal=$(echo "$WITR_JSON"    | jq -r '.resource_context.thermal_state // "Normal"')
prevents_sleep=$(echo "$WITR_JSON" | jq -r '.resource_context.prevents_sleep // false')
app_napped=$(echo "$WITR_JSON" | jq -r '.resource_context.app_napped // false')
warnings=$(echo "$WITR_JSON"   | jq -r '.warnings // [] | length')
fd_count=$(echo "$WITR_JSON"   | jq -r '.process.fd_count // 0')
fd_limit=$(echo "$WITR_JSON"   | jq -r '.process.fd_limit // 1')
bind_addrs=$(echo "$WITR_JSON" | jq -c '.process.bind_addresses // []')
env_vars=$(echo "$WITR_JSON"   | jq -r '.process.env // [] | .[]' 2>/dev/null || true)

SAFE_DAEMONS="mds mds_stores mdworker_shared backupd coreaudiod cloudd bird nsurlsessiond Spotlight trustd syspolicyd coreduetd logd notifyd diskarbitrationd"
is_safe_daemon=false
for d in $SAFE_DAEMONS; do
  if [[ "$cmd" == *"$d"* ]] || [[ "$service" == *"$d"* ]]; then is_safe_daemon=true; break; fi
done

if [[ "$prevents_sleep" == "true" ]] && [[ "$source_type" == "shell" || "$source_type" == "ssh" || "$source_type" == "unknown" ]]; then
  drain_class="inappropriate"; score=$((score+30))
  signals+=("PreventsSleep=true with unattributed source (${source_type})")
fi

if [[ "$thermal" == "Heavy throttling" || "$thermal" == "Trapping" ]]; then
  score=$((score+20))
  if [[ "$source_type" == "unknown" || "$source_type" == "shell" ]]; then
    drain_class="inappropriate"; score=$((score+20))
    signals+=("Thermal=${thermal} with source=${source_type} — runaway candidate")
  else
    signals+=("Thermal=${thermal} — monitor (attributed to ${source_type})")
  fi
fi

if [[ "$health" == "zombie" ]]; then
  locked=$(echo "$WITR_JSON" | jq -r '.file_context.locked_files // [] | length')
  if [[ "$locked" -gt 0 ]]; then
    drain_class="inappropriate"; score=$((score+25))
    signals+=("Zombie process holds ${locked} locked file(s)")
  fi
fi

if [[ "$exe_deleted" == "true" ]]; then
  drain_class="inappropriate"; score=$((score+40))
  signals+=("ExeDeleted=true — possible binary replacement or injected process")
fi

if echo "$env_vars" | grep -qE '^(DYLD_INSERT_LIBRARIES|DYLD_FORCE_FLAT_NAMESPACE|LD_PRELOAD)='; then
  drain_class="inappropriate"; score=$((score+50))
  injected=$(echo "$env_vars" | grep -E '^(DYLD_INSERT_LIBRARIES|DYLD_FORCE_FLAT_NAMESPACE|LD_PRELOAD)=' | head -3)
  signals+=("Library injection env detected: ${injected}")
fi

fd_ratio=$(awk "BEGIN {if ($fd_limit>0) printf \"%.3f\", $fd_count/$fd_limit; else print 0}")
fd_pct=$(awk "BEGIN {printf \"%.0f\", $fd_ratio * 100}")
if awk "BEGIN {exit !($fd_ratio > 0.5)}"; then
  score=$((score+15))
  signals+=("FD pressure: ${fd_count}/${fd_limit} (${fd_pct}%) — exhaustion risk")
  if awk "BEGIN {exit !($fd_ratio > 0.8)}"; then
    drain_class="inappropriate"; score=$((score+15))
  fi
fi

non_loopback=$(echo "$bind_addrs" | jq -r '.[] | select(. != "127.0.0.1" and . != "::1" and . != "")' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$non_loopback" -gt 0 ]] && [[ "$source_type" == "unknown" ]]; then
  drain_class="suspicious"; score=$((score+30))
  signals+=("Non-loopback bind address(es) on unattributed process — rogue listener?")
fi

if [[ "$warnings" -gt 0 ]]; then
  score=$((score+10))
  warn_list=$(echo "$WITR_JSON" | jq -r '.warnings[]' | head -5 | paste -sd '; ' -)
  signals+=("witr warnings (${warnings}): ${warn_list}")
  if [[ "$drain_class" == "appropriate" ]]; then drain_class="suspicious"; fi
fi

if awk "BEGIN {exit !($cpu > 90)}"; then
  score=$((score+10))
  if [[ "$source_type" == "unknown" ]]; then
    drain_class="inappropriate"; score=$((score+10))
    signals+=("CPU=${cpu}% with source=unknown — runaway orphan")
  fi
fi

rss_gb=$(awk "BEGIN {printf \"%.2f\", $rss_bytes/1073741824}")
if awk "BEGIN {exit !($rss_bytes > 1073741824)}"; then
  score=$((score+10))
  signals+=("RSS=${rss_gb}GB — high memory consumer")
fi

if [[ "$app_napped" == "true" ]]; then
  signals+=("AppNapped=true — CPU deprioritised by macOS scheduler")
fi

if [[ "$drain_class" == "appropriate" ]]; then
  if [[ "$is_safe_daemon" == "true" ]]; then
    signals+=("Known safe macOS daemon (${cmd})")
  elif [[ "$source_type" == "launchd" ]] && [[ -n "$service" ]]; then
    signals+=("launchd-attributed service: ${service}")
  fi
fi

if [[ "$score" -gt 100 ]]; then score=100; fi

signals_json=$(printf '%s\n' "${signals[@]}" | jq -R . | jq -s .)

jq -n \
  --arg drain_class "$drain_class" \
  --argjson score "$score" \
  --arg pid "$pid" \
  --arg cmd "$cmd" \
  --arg cpu "$cpu" \
  --arg rss_mb "$rss_mb" \
  --arg source_type "$source_type" \
  --arg thermal "$thermal" \
  --arg health "$health" \
  --argjson signals "$signals_json" \
  --argjson raw "$WITR_JSON" \
  '{drain_class:$drain_class,score:$score,pid:($pid|tonumber? // $pid),command:$cmd,
    cpu_pct:($cpu|tonumber? // 0),rss_mb:($rss_mb|tonumber? // 0),
    source_type:$source_type,thermal_state:$thermal,health:$health,signals:$signals,raw:$raw}'
