#!/bin/bash

IP="52.29.151.247"
SSH_KEY="${1:-~/.ssh/flask-app-key.pem}"
SSH_USER="ubuntu"

echo "Checking Flask app on $IP..."
echo ""

if [ ! -f "$SSH_KEY" ]; then
    echo "SSH key not found: $SSH_KEY"
    exit 1
fi

echo "1. Docker service:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "sudo systemctl status docker --no-pager | head -5"
echo ""

echo "2. Containers:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "sudo docker ps -a"
echo ""

echo "3. Flask app container:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "sudo docker ps -a | grep flask-app || echo 'Not found'"
echo ""

echo "4. Flask app logs (last 30 lines):"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "sudo docker logs flask-app --tail 30 2>&1 || echo 'Could not get logs'"
echo ""

echo "5. Port 5000:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "sudo netstat -tlnp | grep :5000 || sudo ss -tlnp | grep :5000 || echo 'Port 5000 not listening'"
echo ""

echo "6. System resources:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "free -h | head -2; df -h / | tail -1"
echo ""

echo "7. Health check:"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$IP" "curl -s -o /dev/null -w 'HTTP Status: %{http_code}\n' --max-time 5 http://localhost:5000/health || echo 'Health check failed'"
echo ""

echo "Done!"
