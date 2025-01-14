#!/bin/bash

# network-tester.sh
# Network connectivity and performance testing script
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
LOG_FILE="$HOME/.network-tester-$(date +%Y%m%d).log"

# Default values
TARGET_HOST=""
PORT=""
TIMEOUT=5
INTERVAL=1
COUNT=3
MODE="basic"
OUTPUT_FORMAT="text"
VERBOSE=false
CONTINUOUS=false
THRESHOLD_MS=1000
ALERT_EMAIL=""
DNS_SERVERS=("8.8.8.8" "8.8.4.4" "1.1.1.1")
COMMON_PORTS=(80 443 22 21 25 53 3306 5432)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] [HOST]"
    echo
    echo "Options:"
    echo "  -p, --port PORT        Specific port to test"
    echo "  -t, --timeout SEC      Timeout in seconds (default: 5)"
    echo "  -i, --interval SEC     Interval between tests (default: 1)"
    echo "  -c, --count NUM        Number of tests to run (default: 3)"
    echo "  -m, --mode MODE        Test mode (basic|full|port-scan|trace|dns)"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  -w, --watch           Continuous monitoring"
    echo "  -T, --threshold MS     Alert threshold in ms (default: 1000)"
    echo "  -e, --email ADDRESS    Email for alerts"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help message"
    echo
    echo "Modes:"
    echo "  basic     Basic connectivity test (ping)"
    echo "  full      Full network diagnostics"
    echo "  port-scan Common ports availability scan"
    echo "  trace     Traceroute analysis"
    echo "  dns       DNS resolution test"
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
    local deps=("ping" "nc" "dig" "traceroute" "curl" "jq")
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

# Function to send email alert
send_alert() {
    local subject="$1"
    local message="$2"
    
    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    fi
}

# Function to format output
format_output() {
    local content="$1"
    
    case "$OUTPUT_FORMAT" in
        "json")
            echo "$content" | jq -R -s -c 'split("\n")'
            ;;
        "csv")
            echo "$content" | sed 's/\t/,/g'
            ;;
        *)
            echo "$content"
            ;;
    esac
}

# Function to test basic connectivity
test_connectivity() {
    local host="$1"
    local results=()
    local total_time=0
    local packet_loss=0
    
    echo -e "\n${BLUE}Testing connectivity to $host${NC}"
    
    for ((i=1; i<=COUNT; i++)); do
        local start_time=$(date +%s%N)
        if ping -c 1 -W "$TIMEOUT" "$host" >/dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local latency=$(( (end_time - start_time) / 1000000 ))
            results+=("$latency")
            total_time=$((total_time + latency))
            echo -e "${GREEN}Ping $i: ${latency}ms${NC}"
        else
            results+=("timeout")
            packet_loss=$((packet_loss + 1))
            echo -e "${RED}Ping $i: Failed${NC}"
        fi
        
        [ "$i" -lt "$COUNT" ] && sleep "$INTERVAL"
    done
    
    # Calculate statistics
    if [ $packet_loss -lt $COUNT ]; then
        local avg_time=$((total_time / (COUNT - packet_loss)))
        local loss_percent=$((packet_loss * 100 / COUNT))
        echo -e "\nResults:"
        echo -e "Average latency: ${avg_time}ms"
        echo -e "Packet loss: ${loss_percent}%"
        
        # Check threshold
        if [ $avg_time -gt $THRESHOLD_MS ]; then
            send_alert "High Latency Alert" "Average latency to $host is ${avg_time}ms (threshold: ${THRESHOLD_MS}ms)"
        fi
    else
        echo -e "\n${RED}All pings failed${NC}"
        send_alert "Connectivity Alert" "All pings to $host failed"
    fi
}

# Function to test port availability
test_port() {
    local host="$1"
    local port="$2"
    
    echo -e "\n${BLUE}Testing port $port on $host${NC}"
    
    if nc -zv -w "$TIMEOUT" "$host" "$port" 2>/dev/null; then
        echo -e "${GREEN}Port $port is open${NC}"
        return 0
    else
        echo -e "${RED}Port $port is closed${NC}"
        return 1
    fi
}

# Function to perform port scan
port_scan() {
    local host="$1"
    
    echo -e "\n${BLUE}Scanning common ports on $host${NC}"
    
    for port in "${COMMON_PORTS[@]}"; do
        test_port "$host" "$port"
    done
}

# Function to perform DNS tests
test_dns() {
    local host="$1"
    
    echo -e "\n${BLUE}Testing DNS resolution for $host${NC}"
    
    for dns in "${DNS_SERVERS[@]}"; do
        echo -e "\nUsing DNS server $dns:"
        dig "@$dns" "$host" +short
    done
}

# Function to perform traceroute analysis
test_trace() {
    local host="$1"
    
    echo -e "\n${BLUE}Performing traceroute to $host${NC}"
    traceroute -n "$host"
}

# Function to perform full network diagnostics
full_diagnostics() {
    local host="$1"
    
    echo -e "\n${BLUE}Performing full network diagnostics for $host${NC}"
    
    # Basic connectivity
    test_connectivity "$host"
    
    # DNS resolution
    test_dns "$host"
    
    # Common ports
    port_scan "$host"
    
    # Traceroute
    test_trace "$host"
    
    # HTTP(S) response time if web server
    if test_port "$host" 80 || test_port "$host" 443; then
        echo -e "\n${BLUE}Testing HTTP(S) response time${NC}"
        curl -o /dev/null -s -w "Connect: %{time_connect}s\nTTFB: %{time_starttransfer}s\nTotal: %{time_total}s\n" "http://$host"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -w|--watch)
            CONTINUOUS=true
            shift
            ;;
        -T|--threshold)
            THRESHOLD_MS="$2"
            shift 2
            ;;
        -e|--email)
            ALERT_EMAIL="$2"
            shift 2
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
            if [ -z "$TARGET_HOST" ]; then
                TARGET_HOST="$1"
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
if [ -z "$TARGET_HOST" ]; then
    echo "Error: No target host specified"
    print_usage
    exit 1
fi

# Main execution
log_message "INFO" "Starting network tests for $TARGET_HOST"

while true; do
    case "$MODE" in
        "basic")
            test_connectivity "$TARGET_HOST"
            ;;
        "full")
            full_diagnostics "$TARGET_HOST"
            ;;
        "port-scan")
            port_scan "$TARGET_HOST"
            ;;
        "trace")
            test_trace "$TARGET_HOST"
            ;;
        "dns")
            test_dns "$TARGET_HOST"
            ;;
        *)
            echo "Error: Invalid mode $MODE"
            exit 1
            ;;
    esac
    
    if [ "$CONTINUOUS" = false ]; then
        break
    fi
    
    sleep "$INTERVAL"
done

log_message "INFO" "Network tests completed"
echo -e "\n${GREEN}Tests complete. See $LOG_FILE for detailed log.${NC}"
