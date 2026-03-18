#!/bin/bash
# Installs all Prometheus exporters for whole-house monitoring
# Run inside WSL2 Ubuntu on each machine (ST-Gabriel and Maria)
set -euo pipefail

ROLE="${1:-orchestrator}"  # "orchestrator" (ST-Gabriel) or "executor" (Maria)
MACHINE_ID="${2:-st-gabriel}"

echo "=== Whole House Monitoring — Exporter Setup ==="
echo "Role: $ROLE"
echo "Machine: $MACHINE_ID"

# 1. Node Exporter — OS-level metrics (CPU, RAM, disk, network, systemd)
echo "[1/5] Installing node_exporter..."
if ! command -v node_exporter &> /dev/null; then
    NODE_EXPORTER_VERSION="1.8.2"
    curl -fsSL "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" | tar xz -C /tmp/
    sudo cp "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
    rm -rf "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"

    # Create systemd service
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
ExecStart=/usr/local/bin/node_exporter \
    --collector.systemd \
    --collector.processes \
    --collector.tcpstat \
    --collector.diskstats \
    --collector.filesystem \
    --collector.netstat \
    --collector.logind \
    --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF
    sudo useradd -rs /bin/false node_exporter 2>/dev/null || true
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
    echo "  Installed node_exporter v${NODE_EXPORTER_VERSION} on :9100"
else
    echo "  node_exporter already installed"
fi

# 2. cAdvisor — Docker container metrics
echo "[2/5] Installing cAdvisor..."
if command -v docker &> /dev/null; then
    docker pull gcr.io/cadvisor/cadvisor:latest 2>/dev/null || true
    echo "  cAdvisor image pulled. Start with:"
    echo "    docker run -d --name cadvisor \\"
    echo "      --volume=/:/rootfs:ro \\"
    echo "      --volume=/var/run:/var/run:rw \\"
    echo "      --volume=/sys:/sys:ro \\"
    echo "      --volume=/var/lib/docker/:/var/lib/docker:ro \\"
    echo "      -p 8081:8080 \\"
    echo "      gcr.io/cadvisor/cadvisor:latest"
else
    echo "  Docker not available — skipping cAdvisor"
fi

# 3. PostgreSQL Exporter (orchestrator only)
if [ "$ROLE" = "orchestrator" ]; then
    echo "[3/5] Installing postgres_exporter..."
    if ! command -v postgres_exporter &> /dev/null; then
        PG_EXPORTER_VERSION="0.15.0"
        curl -fsSL "https://github.com/prometheus-community/postgres_exporter/releases/download/v${PG_EXPORTER_VERSION}/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64.tar.gz" | tar xz -C /tmp/
        sudo cp "/tmp/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64/postgres_exporter" /usr/local/bin/
        rm -rf "/tmp/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64"

        sudo tee /etc/systemd/system/postgres_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Prometheus PostgreSQL Exporter
After=postgresql.service

[Service]
Type=simple
User=postgres_exporter
Environment="DATA_SOURCE_NAME=postgresql://telemetry_reader@localhost:5432/openclaw_telemetry?sslmode=disable"
ExecStart=/usr/local/bin/postgres_exporter \
    --web.listen-address=:9187

[Install]
WantedBy=multi-user.target
EOF
        sudo useradd -rs /bin/false postgres_exporter 2>/dev/null || true
        sudo systemctl daemon-reload
        sudo systemctl enable postgres_exporter
        echo "  Installed postgres_exporter v${PG_EXPORTER_VERSION} on :9187"
        echo "  NOTE: Set DATA_SOURCE_NAME password before starting"
    else
        echo "  postgres_exporter already installed"
    fi
else
    echo "[3/5] Skipping postgres_exporter (orchestrator only)"
fi

# 4. Smartctl Exporter — SSD/disk health
echo "[4/5] Installing smartctl_exporter..."
if ! command -v smartctl_exporter &> /dev/null; then
    sudo apt-get install -y smartmontools 2>/dev/null || true
    SMART_VERSION="0.12.0"
    curl -fsSL "https://github.com/prometheus-community/smartctl_exporter/releases/download/v${SMART_VERSION}/smartctl_exporter-${SMART_VERSION}.linux-amd64.tar.gz" | tar xz -C /tmp/ 2>/dev/null || true
    if [ -f "/tmp/smartctl_exporter-${SMART_VERSION}.linux-amd64/smartctl_exporter" ]; then
        sudo cp "/tmp/smartctl_exporter-${SMART_VERSION}.linux-amd64/smartctl_exporter" /usr/local/bin/
        sudo tee /etc/systemd/system/smartctl_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Prometheus Smartctl Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/smartctl_exporter --web.listen-address=:9633
PrivilegedPort=false
AmbientCapabilities=CAP_SYS_RAWIO

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable smartctl_exporter
        echo "  Installed smartctl_exporter on :9633"
    else
        echo "  smartctl_exporter download failed — install manually"
    fi
else
    echo "  smartctl_exporter already installed"
fi

# 5. Configure Fluent Bit for OS logs → Loki
echo "[5/5] Configuring Fluent Bit for OS log collection..."
cat << 'LOGCONF' | sudo tee /etc/fluent-bit/os-logs.conf > /dev/null
# Ubuntu OS log collection — feeds into Loki via OTel Collector

[INPUT]
    Name          tail
    Path          /var/log/syslog
    Tag           os.syslog
    Parser        syslog-rfc3164
    Refresh_Interval 5

[INPUT]
    Name          tail
    Path          /var/log/auth.log
    Tag           os.auth
    Parser        syslog-rfc3164
    Refresh_Interval 2

[INPUT]
    Name          tail
    Path          /var/log/kern.log
    Tag           os.kernel
    Parser        syslog-rfc3164
    Refresh_Interval 5

[INPUT]
    Name          tail
    Path          /var/log/apt/history.log
    Tag           os.apt
    Refresh_Interval 30

[INPUT]
    Name          tail
    Path          /var/log/dpkg.log
    Tag           os.dpkg
    Refresh_Interval 30

[INPUT]
    Name          systemd
    Tag           os.systemd
    Systemd_Filter _SYSTEMD_UNIT=sshd.service
    Systemd_Filter _SYSTEMD_UNIT=docker.service
    Systemd_Filter _SYSTEMD_UNIT=ollama.service
    Systemd_Filter _SYSTEMD_UNIT=postgresql.service
    Systemd_Filter _SYSTEMD_UNIT=node_exporter.service
    Systemd_Filter _SYSTEMD_UNIT=grafana-server.service
    Systemd_Filter _SYSTEMD_UNIT=prometheus.service
    Read_From_Tail On
LOGCONF

echo "  OS log collection config written to /etc/fluent-bit/os-logs.conf"
echo "  Include this in main fluent-bit.conf with: @INCLUDE /etc/fluent-bit/os-logs.conf"

echo ""
echo "=== Exporter Setup Complete ==="
echo ""
echo "Prometheus scrape targets:"
echo "  node_exporter:      http://localhost:9100/metrics"
echo "  cAdvisor:           http://localhost:8081/metrics"
echo "  postgres_exporter:  http://localhost:9187/metrics  (orchestrator only)"
echo "  smartctl_exporter:  http://localhost:9633/metrics"
echo "  ollama-metrics:     http://localhost:8080/metrics  (if running)"
echo ""
echo "Add these to your Prometheus config (prometheus.yml):"
echo "  See infra/exporters/config/prometheus-scrape-targets.yml"
