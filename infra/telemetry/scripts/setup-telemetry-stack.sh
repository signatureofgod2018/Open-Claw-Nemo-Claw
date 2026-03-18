#!/bin/bash
# Installs and configures the telemetry stack on a machine
# Run on both ST-Gabriel (full stack) and Maria (collector only)
set -euo pipefail

ROLE="${1:-orchestrator}"  # "orchestrator" (ST-Gabriel) or "executor" (Maria)
MACHINE_ID="${2:-st-gabriel}"

echo "=== Telemetry Stack Setup ==="
echo "Role: $ROLE"
echo "Machine: $MACHINE_ID"

# 1. Install Fluent Bit (log collector — both machines)
echo "[1/5] Installing Fluent Bit..."
if ! command -v fluent-bit &> /dev/null; then
  curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
  echo "  Installed Fluent Bit"
else
  echo "  Fluent Bit already installed: $(fluent-bit --version)"
fi

# 2. Install OpenTelemetry Collector (orchestrator only)
if [ "$ROLE" = "orchestrator" ]; then
  echo "[2/5] Installing OpenTelemetry Collector..."
  if ! command -v otelcol &> /dev/null; then
    # Download latest otelcol-contrib
    OTEL_VERSION="0.96.0"
    curl -fsSL "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_linux_amd64.tar.gz" | tar xz -C /usr/local/bin/
    echo "  Installed OTel Collector v${OTEL_VERSION}"
  else
    echo "  OTel Collector already installed"
  fi

  # 3. Install Prometheus (orchestrator only)
  echo "[3/5] Installing Prometheus..."
  if ! command -v prometheus &> /dev/null; then
    PROM_VERSION="2.51.0"
    curl -fsSL "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz" | tar xz -C /opt/
    ln -sf "/opt/prometheus-${PROM_VERSION}.linux-amd64/prometheus" /usr/local/bin/prometheus
    echo "  Installed Prometheus v${PROM_VERSION}"
  else
    echo "  Prometheus already installed"
  fi

  # 4. Install Loki (orchestrator only)
  echo "[4/5] Installing Loki..."
  if ! command -v loki &> /dev/null; then
    LOKI_VERSION="2.9.4"
    curl -fsSL "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip" -o /tmp/loki.zip
    unzip -o /tmp/loki.zip -d /usr/local/bin/
    chmod +x /usr/local/bin/loki-linux-amd64
    ln -sf /usr/local/bin/loki-linux-amd64 /usr/local/bin/loki
    rm /tmp/loki.zip
    echo "  Installed Loki v${LOKI_VERSION}"
  else
    echo "  Loki already installed"
  fi

  # 5. Install Grafana (orchestrator only)
  echo "[5/5] Installing Grafana..."
  if ! command -v grafana-server &> /dev/null; then
    apt-get install -y apt-transport-https software-properties-common
    wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
    apt-get update && apt-get install -y grafana
    echo "  Installed Grafana"
  else
    echo "  Grafana already installed"
  fi
else
  echo "[2-5/5] Skipping orchestrator-only components (Prometheus, Loki, Grafana, OTel Collector)"
fi

# Configure Fluent Bit
echo ""
echo "=== Configuring Fluent Bit ==="
mkdir -p /etc/fluent-bit
cp infra/telemetry/config/fluentbit-config.conf /etc/fluent-bit/fluent-bit.conf

# Set machine identity
sed -i "s/\${MACHINE_ID}/$MACHINE_ID/g" /etc/fluent-bit/fluent-bit.conf

if [ "$ROLE" = "orchestrator" ]; then
  sed -i "s/\${OTEL_COLLECTOR_HOST}/localhost/g" /etc/fluent-bit/fluent-bit.conf
else
  echo "  NOTE: Set OTEL_COLLECTOR_HOST in /etc/fluent-bit/fluent-bit.conf to ST-Gabriel's IP"
fi

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "  1. Generate mTLS certificates for secure transport"
echo "  2. Configure alert routing (infra/telemetry/policies/alert-routing.yml)"
echo "  3. Import Grafana dashboards from infra/telemetry/config/grafana-dashboards/"
echo "  4. Start services: fluent-bit, otelcol, prometheus, loki, grafana-server"
