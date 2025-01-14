#!/bin/bash

# port-scanner.sh
# Advanced port scanning and service detection script
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
LOG_FILE="$HOME/.port-scanner-$(date +%Y%m%d).log"

# Default values
TARGET=""
PORT_RANGE="1-1024"
TIMEOUT=1
THREADS=10
OUTPUT_FORMAT="text"
VERBOSE=false
SERVICE_DETECT=false
SAVE_OUTPUT=false
SCAN_TYPE="tcp"
EXCLUDE_PORTS=""
BATCH_MODE=false

# Common service ports
declare -A COMMON_SERVICES
COMMON_SERVICES=(
    [21]="FTP"
    [22]="SSH"
    [23]="Telnet"
    [25]="SMTP"
    [53]="DNS"
    [80]="HTTP"
    [110]="POP3"
    [143]="IMAP"
    [443]="HTTPS"
    [445]="SMB"
    [3306]="MySQL"
    [5432]="PostgreSQL"
    [6379]="Redis"
    [27017]="MongoDB"
)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] TARGET"
    echo
    echo "Options:"
    echo "  -p, --ports RANGE     Port range (default: 1-1024)"
    echo "  -t, --timeout SEC     Connection timeout (default: 1)"
    echo "  -T, --threads NUM     Number of threads (default: 10)"
    echo "  -f, --format FORMAT   Output format (text|json|csv)"
    echo "  -s, --service        Enable service detection"
    echo "  -o, --output FILE    Save results to file"
    echo "  -x, --exclude PORTS   Exclude specific ports"
    echo "  -b, --batch FILE     Batch scan from file"
    echo "  -u, --udp           Include UDP scan"
    echo "  -v, --verbose        Verbose output"
    echo "  -h, --help           Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" >> "$LOG_FILE"
    [ "$VERBOSE" = true ] && echo -e "[$level] ${message}"
}

# Function to check dependencies
check_dependencies() {
    local deps=("nc" "nmap" "parallel")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo "Missing dependencies: ${missing[*]}"
        echo "Please install them using your package manager"
        exit 1
    fi
}

# Function to format output
format_output() {
    local host="$1"
    local port="$2"
    local status="$3"
    local service="$4"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"host":"%s","port":%d,"status":"%s","service":"%s"}\n' \
                "$host" "$port" "$status" "$service"
            ;;
        "csv")
            printf '%s,%d,%s,%s\n' "$host" "$port" "$status" "$service"
            ;;
        *)
            printf "%-20s %-6d %-8s %s\n" "$host" "$port" "$status" "$service"
            ;;
    esac
}

# Function to detect service
detect_service() {
    local port="$1"
    
    if [ -n "${COMMON_SERVICES[$port]:-}" ]; then
        echo "${COMMON_SERVICES[$port]}"
    else
        echo "unknown"
    fi
}

# Function to scan single port
scan_port() {
    local host="$1"
    local port="$2"
    local timeout="$3"
    local scan_type="$4"
    
    case "$scan_type" in
        "tcp")
            if nc -z -w "$timeout" "$host" "$port" 2>/dev/null; then
                echo "open"
            else
                echo "closed"
            fi
            ;;
        "udp")
            if nc -zu -w "$timeout" "$host" "$port" 2>/dev/null; then
                echo "open"
            else
                echo "closed"
            fi
            ;;
    esac
}

# Function to scan port range
scan_port_range() {
    local host="$1"
    local start_port="$2"
    local end_port="$3"
    
    echo -e "\n${BLUE}Scanning $host ports $start_port-$end_port${NC}"
    
    # Create header based on output format
    case "$OUTPUT_FORMAT" in
        "text")
            printf "%-20s %-6s %-8s %s\n" "Host" "Port" "Status" "Service"
            printf "%s\n" "----------------------------------------"
            ;;
    esac
    
    # Generate port list excluding specified ports
    local ports=()
    for ((port=start_port; port<=end_port; port++)); do
        if [[ ! $EXCLUDE_PORTS =~ (^|,)$port(,|$) ]]; then
            ports+=("$port")
        fi
    done
    
    # Parallel port scanning
    printf "%s\n" "${ports[@]}" | parallel -j "$THREADS" scan_single_port "$host" {} "$TIMEOUT" "$SCAN_TYPE"
}

# Function to scan single port and format output
scan_single_port() {
    local host="$1"
    local port="$2"
    local timeout="$3"
    local scan_type="$4"
    
    local status
    status=$(scan_port "$host" "$port" "$timeout" "$scan_type")
    
    if [ "$status" = "open" ]; then
        local service="unknown"
        if [ "$SERVICE_DETECT" = true ]; then
            service=$(detect_service "$port")
        fi
        format_output "$host" "$port" "$status" "$service"
    fi
}

# Function to process single target
process_target() {
    local target="$1"
    
    log_message "INFO" "Starting scan of $target"
    
    # Parse port range
    local start_port
    local end_port
    IFS='-' read -r start_port end_port <<< "$PORT_RANGE"
    
    # Scan ports
    if [ "$SCAN_TYPE" = "both" ]; then
        echo -e "\n${YELLOW}TCP Scan:${NC}"
        scan_port_range "$target" "$start_port" "$end_port" "tcp"
        echo -e "\n${YELLOW}UDP Scan:${NC}"
        scan_port_range "$target" "$start_port" "$end_port" "udp"
    else
        scan_port_range "$target" "$start_port" "$end_port" "$SCAN_TYPE"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--ports)
            PORT_RANGE="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -T|--threads)
            THREADS="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_DETECT=true
            shift
            ;;
        -o|--output)
            SAVE_OUTPUT=true
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_PORTS="$2"
            shift 2
            ;;
        -b|--batch)
            BATCH_MODE=true
            TARGET="$2"
            shift 2
            ;;
        -u|--udp)
            SCAN_TYPE="both"
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$TARGET" ]; then
                TARGET="$1"
            else
                echo "Error: Unknown option $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check dependencies
check_dependencies

# Validate arguments
if [ -z "$TARGET" ]; then
    echo "Error: No target specified"
    print_usage
    exit 1
fi

# Main execution
log_message "INFO" "Starting port scanner"

if [ "$BATCH_MODE" = true ]; then
    # Process targets from file
    while IFS= read -r target || [ -n "$target" ]; do
        [ -z "$target" ] && continue
        [ "${target:0:1}" = "#" ] && continue
        process_target "$target"
        echo "---"
    done < "$TARGET"
else
    # Process single target
    process_target "$TARGET"
fi

log_message "INFO" "Port scan completed"
echo -e "\n${GREEN}Scan complete. See $LOG_FILE for detailed log.${NC}"
