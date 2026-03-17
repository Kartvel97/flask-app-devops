#!/bin/bash
set -euo pipefail

BACKUP_DIR="/opt/backups"

if [ $# -eq 0 ]; then
    LATEST_BACKUP=$(ls -t "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | head -1)
    if [ -z "${LATEST_BACKUP}" ]; then
        echo "No backups found in ${BACKUP_DIR}"
        exit 1
    fi
    BACKUP_FILE="${LATEST_BACKUP}"
else
    BACKUP_FILE="$1"
fi

if [ ! -f "${BACKUP_FILE}" ]; then
    echo "Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

echo "Verifying backup: ${BACKUP_FILE}"

if ! tar tzf "${BACKUP_FILE}" >/dev/null 2>&1; then
    echo "Backup file is corrupted or invalid"
    exit 1
fi

echo "Backup file is valid tar.gz"

TEMP_DIR=$(mktemp -d)
tar xzf "${BACKUP_FILE}" -C "${TEMP_DIR}" >/dev/null 2>&1

BACKUP_NAME=$(basename "${BACKUP_FILE}" .tar.gz)
BACKUP_PATH="${TEMP_DIR}/${BACKUP_NAME}"

if [ ! -f "${BACKUP_PATH}/manifest.json" ]; then
    echo "Manifest file not found"
else
    echo "Manifest file found"
    if command -v jq >/dev/null 2>&1; then
        echo "Backup details:"
        cat "${BACKUP_PATH}/manifest.json" | jq .
    else
        cat "${BACKUP_PATH}/manifest.json"
    fi
fi

REQUIRED_VOLUMES=("prom_data" "grafana_data")
REQUIRED_CONFIGS=("prometheus_config.tar.gz" "grafana_config.tar.gz")

echo "Checking backup components..."

for volume in "${REQUIRED_VOLUMES[@]}"; do
    if [ -f "${BACKUP_PATH}/${volume}.tar.gz" ]; then
        echo "  ${volume} backup found"
    else
        echo "  ${volume} backup missing"
    fi
done

for config in "${REQUIRED_CONFIGS[@]}"; do
    if [ -f "${BACKUP_PATH}/${config}" ]; then
        echo "  ${config} found"
    else
        echo "  ${config} missing"
    fi
done

rm -rf "${TEMP_DIR}"
echo "Verification completed!"

