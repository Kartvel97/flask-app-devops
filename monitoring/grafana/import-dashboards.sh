#!/bin/bash

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-}"

if [ -z "$GRAFANA_PASSWORD" ]; then
    if [ -f "/opt/monitoring/grafana-password.txt" ]; then
        GRAFANA_PASSWORD=$(sudo cat /opt/monitoring/grafana-password.txt)
    else
        echo "Error: GRAFANA_PASSWORD not set"
        exit 1
    fi
fi

DASHBOARDS=(
    "12611:Loki Logs"
    "1860:Prometheus"
    "3489:Alerts"
    "179:Docker Container & Host Metrics"
)

for dashboard in "${DASHBOARDS[@]}"; do
    ID="${dashboard%%:*}"
    NAME="${dashboard##*:}"
    echo "Importing: $NAME (ID: $ID)..."
    curl -X POST \
        -H "Content-Type: application/json" \
        -d "{\"dashboardId\": $ID, \"overwrite\": true}" \
        -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
        "$GRAFANA_URL/api/dashboards/import" || echo "Failed: $NAME"
done

echo "Done!"
