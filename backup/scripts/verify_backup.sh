#!/bin/bash
# Verify Backup Script
# Checks backup integrity and completeness

set -euo pipefail

BACKUP_DIR="/opt/backups"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

if [ $# -eq 0 ]; then
    # Check latest backup
    LATEST_BACKUP=$(ls -t "${BACKUP_DIR}"/backup_*.tar.gz 2>/dev/null | head -1)
    if [ -z "${LATEST_BACKUP}" ]; then
        error "No backups found in ${BACKUP_DIR}"
        exit 1
    fi
    BACKUP_FILE="${LATEST_BACKUP}"
else
    BACKUP_FILE="$1"
fi

if [ ! -f "${BACKUP_FILE}" ]; then
    error "Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

log "Verifying backup: ${BACKUP_FILE}"

# Check if file is readable and valid tar.gz
if ! tar tzf "${BACKUP_FILE}" >/dev/null 2>&1; then
    error "Backup file is corrupted or invalid"
    exit 1
fi

log "✓ Backup file is valid tar.gz"

# Extract and check manifest
TEMP_DIR=$(mktemp -d)
tar xzf "${BACKUP_FILE}" -C "${TEMP_DIR}" >/dev/null 2>&1

BACKUP_NAME=$(basename "${BACKUP_FILE}" .tar.gz)
BACKUP_PATH="${TEMP_DIR}/${BACKUP_NAME}"

if [ ! -f "${BACKUP_PATH}/manifest.json" ]; then
    warning "Manifest file not found"
else
    log "✓ Manifest file found"
    if command -v jq >/dev/null 2>&1; then
        log "Backup details:"
        cat "${BACKUP_PATH}/manifest.json" | jq .
    else
        cat "${BACKUP_PATH}/manifest.json"
    fi
fi

# Check required components
REQUIRED_VOLUMES=("prom_data" "grafana_data")
REQUIRED_CONFIGS=("prometheus_config.tar.gz" "grafana_config.tar.gz")

log "Checking backup components..."

for volume in "${REQUIRED_VOLUMES[@]}"; do
    if [ -f "${BACKUP_PATH}/${volume}.tar.gz" ]; then
        log "  ✓ ${volume} backup found"
    else
        warning "  ✗ ${volume} backup missing"
    fi
done

for config in "${REQUIRED_CONFIGS[@]}"; do
    if [ -f "${BACKUP_PATH}/${config}" ]; then
        log "  ✓ ${config} found"
    else
        warning "  ✗ ${config} missing"
    fi
done

# Cleanup
rm -rf "${TEMP_DIR}"

log "Verification completed!"

