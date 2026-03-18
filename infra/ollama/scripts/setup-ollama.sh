#!/bin/bash
# Installs Ollama with ollama-metrics proxy and AMD ROCm support
# Run inside WSL2 Ubuntu on ST-Gabriel
set -euo pipefail

OLLAMA_PORT=11434
METRICS_PROXY_PORT=8080
MODEL="${1:-mistral-small3.2}"

echo "=== Ollama + Monitoring Stack Setup ==="
echo "Machine: $(hostname)"
echo "Model: $MODEL"

# 1. Install Ollama
echo "[1/5] Installing Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
    echo "  Installed Ollama $(ollama --version 2>/dev/null || echo 'latest')"
else
    echo "  Ollama already installed: $(ollama --version 2>/dev/null)"
fi

# 2. Configure AMD ROCm for RX 6900 XT (RDNA 2)
echo "[2/5] Configuring AMD GPU support..."
if lspci 2>/dev/null | grep -qi "AMD.*Navi"; then
    echo "  AMD GPU detected — setting ROCm override for RDNA 2"
    # RX 6900 XT is gfx1030 but ROCm needs this override
    export HSA_OVERRIDE_GFX_VERSION=10.3.0

    # Persist the environment variable
    if ! grep -q "HSA_OVERRIDE_GFX_VERSION" ~/.bashrc 2>/dev/null; then
        echo 'export HSA_OVERRIDE_GFX_VERSION=10.3.0' >> ~/.bashrc
        echo "  Added HSA_OVERRIDE_GFX_VERSION=10.3.0 to ~/.bashrc"
    fi

    # Also set for Ollama service
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    cat << 'OVERRIDE' | sudo tee /etc/systemd/system/ollama.service.d/amd-gpu.conf > /dev/null
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"
OVERRIDE
    sudo systemctl daemon-reload
    echo "  Configured Ollama service with AMD GPU override"
else
    echo "  No AMD GPU detected in WSL — GPU passthrough may need configuration"
    echo "  See: https://learn.microsoft.com/en-us/windows/ai/directml/gpu-cuda-in-wsl"
fi

# 3. Start Ollama service
echo "[3/5] Starting Ollama service..."
sudo systemctl enable ollama 2>/dev/null || true
sudo systemctl start ollama 2>/dev/null || ollama serve &

# Wait for Ollama to be ready
echo "  Waiting for Ollama to be ready..."
for i in {1..30}; do
    if curl -s http://localhost:${OLLAMA_PORT}/api/tags > /dev/null 2>&1; then
        echo "  Ollama is running on port ${OLLAMA_PORT}"
        break
    fi
    sleep 1
done

# 4. Pull the model
echo "[4/5] Pulling model: $MODEL (this may take a while)..."
ollama pull "$MODEL"
echo "  Model $MODEL ready"

# Verify GPU is being used
echo "  Checking GPU allocation..."
ollama ps 2>/dev/null || echo "  (run 'ollama ps' after first inference to see GPU allocation)"

# 5. Install ollama-metrics proxy
echo "[5/5] Setting up ollama-metrics proxy..."
if command -v docker &> /dev/null; then
    # Use Docker if available
    docker pull ghcr.io/norskhelsenett/ollama-metrics:latest 2>/dev/null || true

    echo "  ollama-metrics can be started with:"
    echo "    docker run -d --name ollama-metrics \\"
    echo "      -e OLLAMA_HOST=http://host.docker.internal:${OLLAMA_PORT} \\"
    echo "      -p ${METRICS_PROXY_PORT}:8080 \\"
    echo "      ghcr.io/norskhelsenett/ollama-metrics:latest"
else
    echo "  Docker not available — install ollama-metrics manually"
    echo "  See: https://github.com/NorskHelsenett/ollama-metrics"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Endpoints:"
echo "  Ollama API:          http://localhost:${OLLAMA_PORT}"
echo "  Metrics proxy:       http://localhost:${METRICS_PROXY_PORT} (after starting ollama-metrics)"
echo "  Prometheus scrape:   http://localhost:${METRICS_PROXY_PORT}/metrics"
echo ""
echo "Quick test:"
echo "  ollama run $MODEL 'Hello, how are you?'"
echo ""
echo "Integration with OpenClaw:"
echo "  Set Ollama as a local inference provider in openclaw.json"
echo "  NemoClaw Privacy Router → http://localhost:${METRICS_PROXY_PORT} (via metrics proxy)"
echo ""
echo "Prometheus scrape config to add:"
echo "  - job_name: 'ollama'"
echo "    static_configs:"
echo "      - targets: ['localhost:${METRICS_PROXY_PORT}']"
