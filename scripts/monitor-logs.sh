#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FLASK_CONTAINER="flask-app"
MONITORING_CONTAINERS=("prometheus" "grafana" "loki" "alertmanager")
LOG_LINES=20
REFRESH_INTERVAL=5

header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

status() {
    local container=$1
    if sudo docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo -e "${GREEN}✓${NC} Running"
    else
        echo -e "${RED}✗${NC} Not running"
    fi
}

errs() {
    local container=$1
    local lines=$2
    echo -e "\n${YELLOW}Errors:${NC}"
    sudo docker logs "$container" --tail 100 2>&1 | \
        grep -iE "error|fail|exception|critical" | \
        tail -"$lines" || echo "No errors found"
}

logs() {
    local container=$1
    local lines=$2
    echo -e "\n${GREEN}Logs:${NC}"
    sudo docker logs "$container" --tail "$lines" 2>&1
}

monitor() {
    while true; do
        clear
        echo -e "${GREEN}=== Flask DevOps - Log Monitor ===${NC}"
        echo -e "Refreshing every ${REFRESH_INTERVAL}s (Ctrl+C to exit)"
        echo ""
        
        header "Flask Application"
        echo -e "Status: $(status $FLASK_CONTAINER)"
        logs "$FLASK_CONTAINER" "$LOG_LINES"
        errs "$FLASK_CONTAINER" 5
        
        for container in "${MONITORING_CONTAINERS[@]}"; do
            header "$(echo $container | tr '[:lower:]' '[:upper:]')"
            echo -e "Status: $(status $container)"
            logs "$container" 10
        done
        
        header "System Errors"
        sudo journalctl --since "5 minutes ago" -p err --no-pager | tail -5 || echo "No system errors"
        
        header "Resource Usage"
        echo -e "${GREEN}Memory:${NC}"
        free -h | grep Mem
        echo -e "\n${GREEN}Disk:${NC}"
        df -h / | tail -1
        
        sleep "$REFRESH_INTERVAL"
    done
}

search_errors() {
    local container=${1:-$FLASK_CONTAINER}
    local pattern=${2:-"error|fail|exception"}
    
    echo -e "${YELLOW}Searching for: $pattern${NC}"
    echo -e "${YELLOW}Container: $container${NC}\n"
    
    sudo docker logs "$container" 2>&1 | \
        grep -iE "$pattern" | \
        tail -50
}

follow_logs() {
    local container=${1:-$FLASK_CONTAINER}
    echo -e "${GREEN}Following logs for: $container${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"
    sudo docker logs "$container" -f
}

usage() {
    echo "Usage: $0 [-m] [-f [container]] [-s [pattern]] [-c name] [-h]"
    echo "  -m monitor, -f follow logs, -s search errors, -c container name"
}

case "${1:-}" in
    -m|--monitor|"")
        monitor
        ;;
    -f|--follow)
        follow_logs "${2:-$FLASK_CONTAINER}"
        ;;
    -s|--search)
        search_errors "${3:-$FLASK_CONTAINER}" "${2:-error|fail|exception}"
        ;;
    -c|--container)
        if [ -z "${2:-}" ]; then
            echo "Error: Container name required"
            usage
            exit 1
        fi
        FLASK_CONTAINER="$2"
        shift 2
        case "${1:-}" in
            -f|--follow)
                follow_logs "$FLASK_CONTAINER"
                ;;
            -s|--search)
                search_errors "$FLASK_CONTAINER" "${2:-error|fail|exception}"
                ;;
            *)
                monitor
                ;;
        esac
        ;;
    -h|--help)
        usage
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
esac

