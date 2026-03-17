#!/bin/bash
# быстрая проверка что метрики собираются

echo "1. Flask in monitoring network:"
sudo docker network inspect monitoring 2>/dev/null | grep -A 5 "flask-app" || echo "Flask app not found in monitoring network"
echo ""

echo "2. Prometheus -> flask-app:"
sudo docker exec prometheus wget -qO- http://flask-app:5000/metrics 2>/dev/null | head -20 || echo "Prometheus cannot reach flask-app:5000/metrics"
echo ""

echo "3. Prometheus targets:"
curl -s http://localhost:9090/api/v1/targets | grep -A 10 "flask-app" || echo "Flask app target not found"
echo ""

echo "4. Metrics endpoint:"
curl -s http://localhost:5000/metrics | head -20 || echo "Cannot reach Flask metrics endpoint"
echo ""

echo "5. http_requests in Prometheus:"
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | grep -i "http_requests" || echo "http_requests_total metric not found in Prometheus"
echo ""

echo "If metrics are missing, try making some requests to Flask app:"
echo "   curl http://localhost:5000/"
echo "   curl http://localhost:5000/health"
echo "   Then check again: curl http://localhost:5000/metrics"
