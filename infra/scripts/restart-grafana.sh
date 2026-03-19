#!/bin/bash
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
sudo systemctl reset-failed grafana-server 2>/dev/null
sudo systemctl start grafana-server
sleep 8
echo "STATUS: $(sudo systemctl is-active grafana-server)"
echo "PORTS:"
ss -tlnp | grep -E '3000|9090|9100|5432'
echo "TEST:"
curl -s -o /dev/null -w "HTTP: %{http_code}\n" http://127.0.0.1:3000/api/health
