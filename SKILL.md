---
name: witr-resource-monitor
description: macOS resource consumption intelligence using witr — inspect CPU, RAM, I/O, FD pressure, thermal state, and sleep assertions per process; classify drain as appropriate vs inappropriate; and emit structured JSON agent context.
tags: [macos, resource-monitoring, performance, cpu, memory, battery, thermal, process-inspector, agent-context, witr]
version: 1.0.0
author: Hani Mikhail
user-invocable: true
disable-model-invocation: false
metadata:
  openclaw:
    emoji: "🔬"
    homepage: "https://github.com/Zpankz/witr-resource-monitor"
    os: ["darwin"]
    requires:
      bins: ["bash", "witr", "jq", "ps", "pmset"]
    install:
      - id: "brew-witr"
        kind: "brew"
        formula: "witr"
        bins: ["witr"]
        label: "Install witr (brew)"
      - id: "brew-jq"
        kind: "brew"
        formula: "jq"
        bins: ["jq"]
        label: "Install jq (brew)"
---

# witr Resource Monitor

Real-time macOS resource consumption analysis using [witr](https://github.com/pranshuparmar/witr).
Inspects CPU, RAM, I/O throughput, file descriptor pressure, thermal throttling, sleep prevention assertions, and launchd service attribution per process. Classifies each finding as **appropriate** (expected daemon behaviour) or **inappropriate** (runaway / malicious / leaking) and returns structured JSON context for agent consumption.

> **macOS only.** Requires witr >= 0.7.0 installed via brew.

## Commands

### /resource-inspect `<process-name-or-pid>`
```bash
bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/inspect.sh <name_or_pid>
```
Output: JSON with `drain_class`, `score`, `signals[]`, and raw witr result.

### /resource-sweep
```bash
bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/sweep.sh
```
Output: Ranked JSON array of top 15 CPU consumers, each classified.

### /resource-thermal
```bash
bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/thermal.sh
```

### /resource-fd-pressure
```bash
bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/fd-pressure.sh
```

### /resource-memory-top
```bash
bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/memory-top.sh [--threshold-mb 500]
```

### /resource-gpu
```bash
sudo bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/gpu.sh
```

### /resource-agent-context
```bash
bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/agent-context.sh
```

## Classification Logic

### Appropriate
- source.type == "launchd" + known daemon (mds, backupd, coreaudiod, cloudd, bird)
- thermal_state == "Normal" + cpu_pct < 80
- prevents_sleep == true + known media/backup daemon

### Inappropriate
- prevents_sleep == true + source.type is shell/ssh/unknown
- thermal Heavy/Trapping + no launchd attribution
- health == "zombie" + locked_files non-empty
- exe_deleted == true
- env contains DYLD_INSERT_LIBRARIES or LD_PRELOAD
- fd_count/fd_limit > 0.5
- bind_addresses on non-loopback + source.type == "unknown"
- cpu_pct > 90 + source.type == "unknown"
- warnings[] non-empty

## Security

All scripts are read-only. No process killing, no config mutation, no network calls.
`gpu.sh` requires sudo only for powermetrics; all other scripts run as current user.

## Requirements

| Tool | Install |
|------|---------|
| witr | `brew install witr` |
| jq | `brew install jq` |
| pmset | pre-installed macOS |
| ps, lsof, ioreg | pre-installed macOS |
