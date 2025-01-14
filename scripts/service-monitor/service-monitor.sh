#!/bin/bash

# service-monitor.sh
# Advanced service monitoring and management script
# Author: Dima
# Date: 2025-01-14

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/service-monitor-$(date +%Y%m%d).log"

# Default values
WATCH_INTERVAL=5  # seconds
NOTIFY_ON_CHANGE=false
EMAIL_RECIPIENT=""
SERVICES_FILE=""
MONITOR_MODE=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] [SERVICE...]"
    echo "Options:"
    echo "  -w, --watch           Monitor services continuously"
    echo "  -i, --interval SEC    Watch interval in seconds (default: 5)"
    echo "  -n, --notify EMAIL    Send email notifications on service status changes"
    echo "  -f, --file FILE       Read service names from file"
    echo "  -a, --all            Show all services"
    echo "  -r, --restart SERVICE Restart specified service"
    echo "  -s, --start SERVICE   Start specified service"
    echo "  -p, --stop SERVICE    Stop specified service"
    echo "  -h, --help           Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" | sudo tee -a "$LOG_FILE"
    echo -e "[$level] ${message}"
}

# Function to detect init system
detect_init_system() {
    if pidof systemd >/dev/null; then
        echo "systemd"
    elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
        echo "sysvinit"
    elif [ -f /etc/init/cron.conf ]; then
        echo "upstart"
    else
        echo "unknown"
    fi
}

# Function to get service status
get_service_status() {
    local service="$1"
    local init_system="$2"
    
    case "$init_system" in
        "systemd")
            systemctl status "$service" 2>/dev/null | grep -E "Active:|Loaded:" || echo "Service not found"
            ;;
        "sysvinit")
            service "$service" status 2>/dev/null || echo "Service not found"
            ;;
        "upstart")
            status "$service" 2>/dev/null || echo "Service not found"
            ;;
        *)
            echo "Unknown init system"
            return 1
            ;;
    esac
}

# Function to control service
control_service() {
    local action="$1"
    local service="$2"
    local init_system="$3"
    
    log_message "INFO" "Attempting to $action service: $service"
    
    case "$init_system" in
        "systemd")
            sudo systemctl "$action" "$service"
            ;;
        "sysvinit")
            sudo service "$service" "$action"
            ;;
        "upstart")
            sudo "$action" "$service"
            ;;
        *)
            log_message "ERROR" "Unknown init system"
            return 1
            ;;
    esac
}

# Function to list all services
list_all_services() {
    local init_system="$1"
    
    case "$init_system" in
        "systemd")
            systemctl list-units --type=service --all
            ;;
        "sysvinit")
            ls -1 /etc/init.d/
            ;;
        "upstart")
            initctl list
            ;;
        *)
            log_message "ERROR" "Unknown init system"
            return 1
            ;;
    esac
}

# Function to monitor services
monitor_services() {
    local services=("$@")
    local init_system=$(detect_init_system)
    local previous_status=()
    local current_status=()
    
    # Initialize previous status
    for service in "${services[@]}"; do
        previous_status+=("$(get_service_status "$service" "$init_system")")
    done
    
    while true; do
        clear
        echo -e "${BLUE}=== Service Monitor (Ctrl+C to exit) ===${NC}"
        echo "Last update: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        
        for i in "${!services[@]}"; do
            current_status[i]="$(get_service_status "${services[i]}" "$init_system")"
            
            echo -e "${YELLOW}Service: ${services[i]}${NC}"
            echo "${current_status[i]}"
            echo
            
            # Check for status change
            if [ "${current_status[i]}" != "${previous_status[i]}" ]; then
                log_message "ALERT" "Status changed for service ${services[i]}"
                
                if [ "$NOTIFY_ON_CHANGE" = true ] && [ -n "$EMAIL_RECIPIENT" ]; then
                    echo "Service ${services[i]} status changed" | \
                        mail -s "Service Status Alert" "$EMAIL_RECIPIENT"
                fi
            fi
            
            previous_status[i]="${current_status[i]}"
        done
        
        sleep "$WATCH_INTERVAL"
    done
}

# Parse command line arguments
SERVICES=()
ACTION=""
TARGET_SERVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--watch)
            MONITOR_MODE=true
            shift
            ;;
        -i|--interval)
            WATCH_INTERVAL="$2"
            shift 2
            ;;
        -n|--notify)
            NOTIFY_ON_CHANGE=true
            EMAIL_RECIPIENT="$2"
            shift 2
            ;;
        -f|--file)
            SERVICES_FILE="$2"
            shift 2
            ;;
        -a|--all)
            ACTION="list-all"
            shift
            ;;
        -r|--restart)
            ACTION="restart"
            TARGET_SERVICE="$2"
            shift 2
            ;;
        -s|--start)
            ACTION="start"
            TARGET_SERVICE="$2"
            shift 2
            ;;
        -p|--stop)
            ACTION="stop"
            TARGET_SERVICE="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            SERVICES+=("$1")
            shift
            ;;
    esac
done

# Main execution
INIT_SYSTEM=$(detect_init_system)
log_message "INFO" "Detected init system: $INIT_SYSTEM"

if [ "$INIT_SYSTEM" = "unknown" ]; then
    log_message "ERROR" "Could not detect init system"
    exit 1
fi

# Read services from file if specified
if [ -n "$SERVICES_FILE" ] && [ -f "$SERVICES_FILE" ]; then
    while IFS= read -r service; do
        [[ -n "$service" && ! "$service" =~ ^[[:space:]]*# ]] && SERVICES+=("$service")
    done < "$SERVICES_FILE"
fi

# Execute requested action
case "$ACTION" in
    "list-all")
        list_all_services "$INIT_SYSTEM"
        ;;
    "restart"|"start"|"stop")
        control_service "$ACTION" "$TARGET_SERVICE" "$INIT_SYSTEM"
        ;;
    "")
        if [ "$MONITOR_MODE" = true ]; then
            if [ ${#SERVICES[@]} -eq 0 ]; then
                log_message "ERROR" "No services specified for monitoring"
                exit 1
            fi
            monitor_services "${SERVICES[@]}"
        else
            # Single status check for specified services
            for service in "${SERVICES[@]}"; do
                echo -e "${YELLOW}Service: $service${NC}"
                get_service_status "$service" "$INIT_SYSTEM"
                echo
            done
        fi
        ;;
esac

log_message "INFO" "Script completed successfully"
