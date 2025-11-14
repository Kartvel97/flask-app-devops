#!/bin/bash

set -e

BACKUP_DIR="/opt/backups"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "Error: Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting restore..."

TEMP_DIR=$(mktemp -d)
echo "Extracting backup..."
tar xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"

BACKUP_NAME=$(basename "${BACKUP_FILE}" .tar.gz)
BACKUP_PATH="${TEMP_DIR}/${BACKUP_NAME}"

if [ ! -d "${BACKUP_PATH}" ]; then
    echo "Error: Invalid backup structure"
    exit 1
fi

if [ -f "${BACKUP_PATH}/manifest.json" ]; then
    echo "Backup manifest:"
    cat "${BACKUP_PATH}/manifest.json"
fi

read -p "Restore from this backup? This will overwrite current data. (yes/no): " confirm
if [ "${confirm}" != "yes" ]; then
    echo "Restore cancelled"
    rm -rf "${TEMP_DIR}"
    exit 0
fi

echo "Stopping services..."
cd /opt/monitoring 2>/dev/null && docker-compose -f docker-compose.monitoring.yml down || true
docker stop flask-app 2>/dev/null || true

echo "Restoring Docker volumes..."
VOLUMES=("prom_data" "grafana_data" "alertmanager_data" "loki_data" "promtail_data")

for volume in "${VOLUMES[@]}"; do
    if [ -f "${BACKUP_PATH}/${volume}.tar.gz" ]; then
        echo "  Restoring volume: ${volume}"
        docker volume rm "${volume}" 2>/dev/null || true
        docker volume create "${volume}"
        docker run --rm \
            -v "${volume}":/target \
            -v "${BACKUP_PATH}":/backup:ro \
            alpine sh -c "cd /target && tar xzf /backup/${volume}.tar.gz"
    fi
done

echo "Restoring configurations..."
CONFIG_ARCHIVES=(
    "prometheus_config.tar.gz:/opt/monitoring"
    "grafana_config.tar.gz:/opt/monitoring"
    "loki_config.tar.gz:/opt/monitoring"
    "promtail_config.tar.gz:/opt/monitoring"
    "flask-app_config.tar.gz:/opt"
)

for archive_path in "${CONFIG_ARCHIVES[@]}"; do
    IFS=':' read -r archive target_dir <<< "${archive_path}"
    if [ -f "${BACKUP_PATH}/${archive}" ]; then
        echo "  Restoring ${archive} to ${target_dir}"
        tar xzf "${BACKUP_PATH}/${archive}" -C "${target_dir}"
    fi
done

echo "Restoring docker-compose files..."
if [ -f "${BACKUP_PATH}/docker-compose.monitoring.yml" ]; then
    cp "${BACKUP_PATH}/docker-compose.monitoring.yml" /opt/monitoring/
fi
if [ -f "${BACKUP_PATH}/docker-compose.app.yml" ]; then
    cp "${BACKUP_PATH}/docker-compose.app.yml" /opt/flask-app/
fi

if [ -f "${BACKUP_PATH}/app_code.bundle" ] || [ -f "${BACKUP_PATH}/app_code.tar.gz" ]; then
    read -p "Restore application code? (yes/no): " restore_code
    if [ "${restore_code}" == "yes" ]; then
        echo "Restoring application code..."
        if [ -f "${BACKUP_PATH}/app_code.bundle" ]; then
            cd /opt/flask-app
            git fetch "${BACKUP_PATH}/app_code.bundle" '*:*' 2>/dev/null || true
        elif [ -f "${BACKUP_PATH}/app_code.tar.gz" ]; then
            tar xzf "${BACKUP_PATH}/app_code.tar.gz" -C /opt/flask-app
        fi
    fi
fi

rm -rf "${TEMP_DIR}"

echo "Restore completed!"
echo "Restart services:"
echo "  cd /opt/monitoring && docker-compose -f docker-compose.monitoring.yml up -d"
echo "  cd /opt/flask-app && docker-compose -f docker-compose.app.yml up -d"
