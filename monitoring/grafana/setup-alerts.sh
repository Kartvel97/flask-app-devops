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

echo "Waiting for Grafana..."
for i in {1..30}; do
    if curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" "$GRAFANA_URL/api/health" > /dev/null 2>&1; then
        echo "Grafana is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Grafana not ready after 30 attempts"
        exit 1
    fi
    sleep 2
done

echo "Getting Prometheus datasource..."
PROM_UID=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    "$GRAFANA_URL/api/datasources" | \
    grep -o '"uid":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$PROM_UID" ]; then
    PROM_UID="prometheus"
fi

echo "Creating alert rules..."
ALERT_GROUP='{
  "name": "flask-app-alerts",
  "interval": "30s",
  "rules": [
    {
      "uid": "flask-app-down",
      "title": "Flask Application Down",
      "condition": "A",
      "data": [{
        "refId": "A",
        "relativeTimeRange": {"from": 300, "to": 0},
        "datasourceUid": "'$PROM_UID'",
        "model": {"expr": "up{job=\"flask-app\"} == 0", "refId": "A"}
      }],
      "noDataState": "Alerting",
      "execErrState": "Alerting",
      "for": "1m",
      "annotations": {
        "description": "Flask application is down",
        "summary": "Flask app is not responding"
      },
      "labels": {"severity": "critical"}
    },
    {
      "uid": "high-error-rate",
      "title": "High Error Rate",
      "condition": "A",
      "data": [{
        "refId": "A",
        "relativeTimeRange": {"from": 300, "to": 0},
        "datasourceUid": "'$PROM_UID'",
        "model": {"expr": "sum(rate(http_requests_total{status_code=~\"5..\"}[5m])) > 0.1", "refId": "A"}
      }],
      "noDataState": "NoData",
      "execErrState": "Alerting",
      "for": "5m",
      "annotations": {
        "description": "High error rate detected",
        "summary": "Error rate is above threshold"
      },
      "labels": {"severity": "warning"}
    },
    {
      "uid": "high-cpu",
      "title": "High CPU Usage",
      "condition": "A",
      "data": [{
        "refId": "A",
        "relativeTimeRange": {"from": 300, "to": 0},
        "datasourceUid": "'$PROM_UID'",
        "model": {"expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80", "refId": "A"}
      }],
      "noDataState": "NoData",
      "execErrState": "Alerting",
      "for": "5m",
      "annotations": {
        "description": "CPU usage is above 80%",
        "summary": "High CPU usage detected"
      },
      "labels": {"severity": "warning"}
    },
    {
      "uid": "low-disk-space",
      "title": "Low Disk Space",
      "condition": "A",
      "data": [{
        "refId": "A",
        "relativeTimeRange": {"from": 300, "to": 0},
        "datasourceUid": "'$PROM_UID'",
        "model": {"expr": "(node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100 < 10", "refId": "A"}
      }],
      "noDataState": "NoData",
      "execErrState": "Alerting",
      "for": "5m",
      "annotations": {
        "description": "Disk space is below 10%",
        "summary": "Low disk space warning"
      },
      "labels": {"severity": "critical"}
    }
  ]
}'

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASSWORD" \
    -d "$ALERT_GROUP" \
    "$GRAFANA_URL/api/ruler/grafana/api/v1/rules/flask-app-alerts")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "Alert rules created successfully"
else
    echo "Failed to create alert rules (HTTP $HTTP_CODE)"
fi

echo "Done!"
