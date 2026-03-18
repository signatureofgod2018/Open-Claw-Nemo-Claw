# Grafana Dashboards

Three dashboards to be provisioned:

## 1. gateway-health.json
- OpenClaw Gateway uptime, request rate, error rate, latency
- WebSocket connection count (brute force detection)
- Auth failure rate

## 2. security-telemetry.json
- Tool invocation heatmap by agent (anomaly detection)
- Memory write rate by agent (poisoning detection)
- Network requests by host (exfiltration detection)
- Sandbox violation count (escape detection)
- Skill invocations by source (supply chain monitoring)
- Active alerts panel

## 3. cross-machine.json
- ST-Gabriel <-> Maria transport health
- Message rate, latency, auth failures
- Correlated event traces across machines
- Per-machine resource utilization

Dashboards will be created as JSON models when the telemetry stack is running.
