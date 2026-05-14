# witr-resource-monitor

> **macOS process resource intelligence skill for AI agents**

Uses [witr](https://github.com/pranshuparmar/witr) to inspect CPU, RAM, I/O, file descriptor pressure, thermal throttling, and sleep assertions per process. Classifies each drain as **appropriate**, **suspicious**, or **inappropriate** and emits structured JSON for LLM context ingestion.

## Quick Start

```bash
brew install witr jq
git clone https://github.com/Zpankz/witr-resource-monitor.git \
  ~/.openclaw/workspace/skills/witr-resource-monitor
chmod +x ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/*.sh
bash ~/.openclaw/workspace/skills/witr-resource-monitor/scripts/install-check.sh
```

## Commands

| Command | Description |
|---------|-------------|
| `/resource-inspect <pid\|name>` | Deep single-process inspection |
| `/resource-sweep` | Rank top 15 CPU consumers with classification |
| `/resource-thermal` | Thermal state, CPU speed limit, sleep assertions |
| `/resource-fd-pressure` | Processes above FD exhaustion threshold |
| `/resource-memory-top` | Processes above RAM threshold |
| `/resource-gpu` | GPU utilisation (sudo) or thermal proxy |
| `/resource-agent-context` | Consolidated agent-ready JSON blob |

## Classification Engine

Pipe any `witr --json --verbose` output into `scripts/classify.sh`:

```bash
witr Spotlight --verbose --json --warnings --env | bash scripts/classify.sh
```

Returns `drain_class` (appropriate/suspicious/inappropriate), `score` 0-100, and `signals[]` explaining each finding.

## License

MIT
