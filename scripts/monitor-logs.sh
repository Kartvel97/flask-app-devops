#!/bin/bash
# Real-time log monitoring script for DevOps

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLASK_CONTAINER="flask-app"
MONITORING_CONTAINERS=("prometheus" "grafana" "loki" "alertmanager")
LOG_LINES=20
REFRESH_INTERVAL=5

# Function to print header
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to check container status
check_container() {
    local container=$1
    if sudo docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        echo -e "${GREEN}✓${NC} Running"
    else
        echo -e "${RED}✗${NC} Not running"
    fi
}

# Function to show recent errors
show_errors() {
    local container=$1
    local lines=$2
    echo -e "\n${YELLOW}Recent errors:${NC}"
    sudo docker logs "$container" --tail 100 2>&1 | \
        grep -iE "error|fail|exception|critical" | \
        tail -"$lines" || echo "No errors found"
}

# Function to show logs
show_logs() {
    local container=$1
    local lines=$2
    echo -e "\n${GREEN}Recent logs (last $lines lines):${NC}"
    sudo docker logs "$container" --tail "$lines" 2>&1
}

# Main monitoring loop
monitor() {
    while true; do
        clear
        echo -e "${GREEN}=== Flask DevOps - Log Monitor ===${NC}"
        echo -e "Refreshing every ${REFRESH_INTERVAL}s (Ctrl+C to exit)"
        echo ""
        
        # Flask App
        print_header "Flask Application"
        echo -e "Status: $(check_container $FLASK_CONTAINER)"
        show_logs "$FLASK_CONTAINER" "$LOG_LINES"
        show_errors "$FLASK_CONTAINER" 5
        
        # Monitoring Stack
        for container in "${MONITORING_CONTAINERS[@]}"; do
            print_header "$(echo $container | tr '[:lower:]' '[:upper:]')"
            echo -e "Status: $(check_container $container)"
            show_logs "$container" 10
        done
        
        # System logs
        print_header "System Errors (last 5 minutes)"
        sudo journalctl --since "5 minutes ago" -p err --no-pager | tail -5 || echo "No system errors"
        
        # Resource usage
        print_header "Resource Usage"
        echo -e "${GREEN}Memory:${NC}"
        free -h | grep Mem
        echo -e "\n${GREEN}Disk:${NC}"
        df -h / | tail -1
        
        sleep "$REFRESH_INTERVAL"
    done
}

# Error search mode
search_errors() {
    local container=${1:-$FLASK_CONTAINER}
    local pattern=${2:-"error|fail|exception"}
    
    echo -e "${YELLOW}Searching for: $pattern${NC}"
    echo -e "${YELLOW}Container: $container${NC}\n"
    
    sudo docker logs "$container" 2>&1 | \
        grep -iE "$pattern" | \
        tail -50
}

# Follow mode
follow_logs() {
    local container=${1:-$FLASK_CONTAINER}
    echo -e "${GREEN}Following logs for: $container${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"
    sudo docker logs "$container" -f
}

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
    -m, --monitor          Monitor all containers (default)
    -f, --follow [CONTAINER]  Follow logs for specific container
    -s, --search [PATTERN]    Search for errors in logs
    -c, --container NAME      Container name (default: flask-app)
    -h, --help             Show this help

Examples:
    $0                      # Monitor all containers
    $0 -f flask-app         # Follow Flask app logs
    $0 -s "timeout|504"     # Search for timeout errors
    $0 -c prometheus -f     # Follow Prometheus logs
EOF
}

# Parse arguments
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

