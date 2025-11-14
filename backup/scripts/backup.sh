#!/bin/bash

set -e

BACKUP_DIR="/opt/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
RETENTION_DAYS=7

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting backup..."

mkdir -p "${BACKUP_PATH}"

echo "Backing up Docker volumes..."
VOLUMES=("prom_data" "grafana_data" "alertmanager_data" "loki_data" "promtail_data")

for volume in "${VOLUMES[@]}"; do
    if docker volume inspect "${volume}" >/dev/null 2>&1; then
        echo "  Backing up volume: ${volume}"
        docker run --rm \
            -v "${volume}":/source:ro \
            -v "${BACKUP_PATH}":/backup \
            alpine tar czf "/backup/${volume}.tar.gz" -C /source .
    fi
done

echo "Backing up configurations..."
CONFIG_DIRS=(
    "/opt/monitoring/prometheus"
    "/opt/monitoring/grafana"
    "/opt/monitoring/loki"
    "/opt/monitoring/promtail"
    "/opt/flask-app"
)

for dir in "${CONFIG_DIRS[@]}"; do
    if [ -d "${dir}" ]; then
        dir_name=$(basename "${dir}")
        echo "  Backing up: ${dir}"
        tar czf "${BACKUP_PATH}/${dir_name}_config.tar.gz" -C "$(dirname "${dir}")" "${dir_name}" 2>/dev/null || true
    fi
done

echo "Backing up docker-compose files..."
if [ -f "/opt/monitoring/docker-compose.monitoring.yml" ]; then
    cp /opt/monitoring/docker-compose.monitoring.yml "${BACKUP_PATH}/"
fi
if [ -f "/opt/flask-app/docker-compose.app.yml" ]; then
    cp /opt/flask-app/docker-compose.app.yml "${BACKUP_PATH}/"
fi

echo "Backing up application code..."
if [ -d "/opt/flask-app/.git" ]; then
    cd /opt/flask-app
    git bundle create "${BACKUP_PATH}/app_code.bundle" --all 2>/dev/null || \
        tar czf "${BACKUP_PATH}/app_code.tar.gz" --exclude='.git' --exclude='venv' --exclude='__pycache__' .
fi

echo "Creating backup manifest..."
cat > "${BACKUP_PATH}/manifest.json" <<EOF
{
    "timestamp": "${TIMESTAMP}",
    "backup_date": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "backup_size": "$(du -sh "${BACKUP_PATH}" | cut -f1)"
}
EOF

echo "Compressing backup..."
cd "${BACKUP_DIR}"
tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"

BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
BACKUP_SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)

echo "Backup completed: ${BACKUP_FILE} (${BACKUP_SIZE})"

if command -v aws >/dev/null 2>&1; then
    S3_BUCKET="${S3_BUCKET:-}"
    
    if [ -z "${S3_BUCKET}" ]; then
        S3_BUCKET=$(aws ec2 describe-tags \
            --filters "Name=resource-type,Values=instance" "Name=key,Values=S3BackupBucket" \
            --query 'Tags[0].Value' \
            --output text 2>/dev/null || echo "")
    fi
    
    if [ -z "${S3_BUCKET}" ]; then
        S3_BUCKET=$(aws s3 ls 2>/dev/null | grep "flask-app-backups" | awk '{print $3}' | head -1 || echo "")
    fi
    
    if [ -n "${S3_BUCKET}" ]; then
        echo "Uploading to S3: ${S3_BUCKET}"
        S3_KEY="backups/${BACKUP_NAME}.tar.gz"
        if aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/${S3_KEY}" 2>/dev/null; then
            echo "Uploaded to S3: s3://${S3_BUCKET}/${S3_KEY}"
        else
            echo "S3 upload failed, backup saved locally only"
        fi
    else
        echo "S3 bucket not configured, backup saved locally only"
    fi
else
    echo "AWS CLI not found, backup saved locally only"
fi

echo "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "backup_*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete

echo "Done!"
