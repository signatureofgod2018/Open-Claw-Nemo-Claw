# Custom Telemetry Exporters

TypeScript modules that parse OpenClaw and NemoClaw events into structured telemetry.

## Planned Exporters

### openclaw-metrics-exporter.ts
- Subscribes to OpenClaw Gateway WebSocket events
- Emits Prometheus metrics: request rate, error rate, latency, auth events
- Emits structured logs: tool invocations, memory writes, skill executions
- Tags each event with agent_id, tool name, risk level

### nemoclaw-audit-exporter.ts
- Tails NemoClaw audit log
- Parses policy violations into structured telemetry events
- Detects sandbox escape signals (TOCTOU patterns, unexpected file access)
- Emits Prometheus counters for violation types

### transport-monitor.ts
- Monitors the mTLS connection between ST-Gabriel and Maria
- Tracks message rate, latency, auth failures
- Generates correlation IDs for cross-machine task tracing
- Alerts on transport degradation or failure

All exporters emit to the OpenTelemetry Collector via OTLP protocol.
Will be implemented when OpenClaw + NemoClaw are running on the Linux partition.
