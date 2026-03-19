# AgenticOS — WSL2 Port Forwarding Setup
# RIGHT-CLICK THIS FILE → "Run with PowerShell" as Administrator
#
# This forwards Windows localhost ports to the WSL2 Ubuntu instance
# so you can access Grafana, Prometheus, etc. from your browser.

Write-Host "=== AgenticOS Port Forwarding Setup ===" -ForegroundColor Cyan
Write-Host ""

# Get the WSL2 IP dynamically
$wslIP = (wsl -d Ubuntu-24.04 -- bash -c "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'") | Out-String
$wslIP = $wslIP.Trim()

if ([string]::IsNullOrEmpty($wslIP)) {
    Write-Host "ERROR: Could not get WSL2 IP address. Is Ubuntu-24.04 running?" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "WSL2 IP: $wslIP" -ForegroundColor Green
Write-Host ""

# Ports to forward
$ports = @(
    @{Port=3000; Name="Grafana"},
    @{Port=9090; Name="Prometheus"},
    @{Port=9100; Name="node_exporter"},
    @{Port=5432; Name="PostgreSQL"},
    @{Port=11434; Name="Ollama"},
    @{Port=8080; Name="ollama-metrics"}
)

# Clear old rules
Write-Host "Clearing old port forwarding rules..." -ForegroundColor Yellow
foreach ($p in $ports) {
    netsh interface portproxy delete v4tov4 listenport=$($p.Port) listenaddress=0.0.0.0 2>$null
}

# Add new rules
Write-Host "Adding port forwarding rules..." -ForegroundColor Yellow
foreach ($p in $ports) {
    netsh interface portproxy add v4tov4 listenport=$($p.Port) listenaddress=0.0.0.0 connectport=$($p.Port) connectaddress=$wslIP
    Write-Host "  $($p.Name): localhost:$($p.Port) -> ${wslIP}:$($p.Port)" -ForegroundColor Green
}

# Add firewall rules
Write-Host ""
Write-Host "Adding Windows Firewall rules..." -ForegroundColor Yellow
$portList = ($ports | ForEach-Object { $_.Port }) -join ","
Remove-NetFirewallRule -DisplayName "AgenticOS WSL2 Ports" -ErrorAction SilentlyContinue 2>$null
New-NetFirewallRule -DisplayName "AgenticOS WSL2 Ports" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $portList | Out-Null
Write-Host "  Firewall rule 'AgenticOS WSL2 Ports' created for ports: $portList" -ForegroundColor Green

# Show all rules
Write-Host ""
Write-Host "=== Active Port Forwarding Rules ===" -ForegroundColor Cyan
netsh interface portproxy show v4tov4

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Cyan
Write-Host "Try in your browser:" -ForegroundColor White
Write-Host "  Grafana:    http://localhost:3000" -ForegroundColor Green
Write-Host "  Prometheus: http://localhost:9090" -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to exit"
