#!/usr/bin/env bash
# Verify all runtime dependencies
set -euo pipefail
PASS=true
echo "witr-resource-monitor dependency check"
echo "----------------------------------------"
for tool in witr jq ps pmset lsof ioreg; do
  if command -v "$tool" &>/dev/null; then
    version=$("$tool" --version 2>/dev/null | head -1 || echo "ok")
    printf "OK   %-12s %s\n" "$tool" "$version"
  else
    printf "FAIL %-12s NOT FOUND — brew install %s\n" "$tool" "$tool"
    PASS=false
  fi
done
echo ""
if [[ "$PASS" == "true" ]]; then echo "All dependencies satisfied."; exit 0
else echo "Missing dependencies."; exit 1; fi
