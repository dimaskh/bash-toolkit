#!/bin/bash

# bandwidth-monitor.sh
# Network bandwidth monitoring and analysis script
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
LOG_FILE="$HOME/.bandwidth-monitor-$(date +%Y%m%d).log"

# Default values
INTERFACE=""
INTERVAL=1
UNIT="MB"
OUTPUT_FORMAT="text"
THRESHOLD=""
ALERT_EMAIL=""
VERBOSE=false
CONTINUOUS=true
LOG_DATA=false
GRAPH_OUTPUT=false
TOP_PROCESSES=false
HISTORICAL=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -i, --interface IF     Network interface to monitor"
    echo "  -n, --interval SEC     Update interval in seconds (default: 1)"
    echo "  -u, --unit UNIT        Display unit (B|KB|MB|GB)"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  -t, --threshold VAL    Alert threshold (in specified unit)"
    echo "  -e, --email ADDRESS    Email for alerts"
    echo "  -l, --log             Log data to file"
    echo "  -g, --graph           Show ASCII graph"
    echo "  -p, --processes       Show top bandwidth processes"
    echo "  -H, --history         Show historical data"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help message"
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
    local deps=("awk" "bc" "nethogs" "iftop")
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

# Function to list available interfaces
list_interfaces() {
    echo "Available network interfaces:"
    ip -o link show | awk -F': ' '{print $2}'
}

# Function to convert bytes to specified unit
convert_unit() {
    local bytes=$1
    
    case "$UNIT" in
        "B")
            echo "$bytes"
            ;;
        "KB")
            echo "scale=2; $bytes/1024" | bc
            ;;
        "MB")
            echo "scale=2; $bytes/1048576" | bc
            ;;
        "GB")
            echo "scale=2; $bytes/1073741824" | bc
            ;;
    esac
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
    local timestamp="$1"
    local rx_speed="$2"
    local tx_speed="$3"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"timestamp":"%s","rx_speed":%.2f,"tx_speed":%.2f,"unit":"%s"}\n' \
                "$timestamp" "$rx_speed" "$tx_speed" "$UNIT"
            ;;
        "csv")
            printf '%s,%.2f,%.2f,%s\n' "$timestamp" "$rx_speed" "$tx_speed" "$UNIT"
            ;;
        *)
            printf '%s - RX: %.2f %s/s | TX: %.2f %s/s\n' \
                "$timestamp" "$rx_speed" "$UNIT" "$tx_speed" "$UNIT"
            ;;
    esac
}

# Function to draw ASCII graph
draw_graph() {
    local value=$1
    local max=$2
    local width=50
    local chars=$(printf "%.0f" $(echo "scale=2; $value/$max*$width" | bc))
    printf "["
    for ((i=0; i<chars; i++)); do
        printf "#"
    done
    for ((i=chars; i<width; i++)); do
        printf " "
    done
    printf "]"
}

# Function to get network statistics
get_network_stats() {
    local interface="$1"
    local rx_bytes
    local tx_bytes
    
    rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
    tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")
    
    echo "$rx_bytes $tx_bytes"
}

# Function to show top bandwidth processes
show_top_processes() {
    echo -e "\n${BLUE}Top Bandwidth Processes:${NC}"
    sudo nethogs -t "$INTERFACE" -v 0 | head -n 6
}

# Function to show historical data
show_historical_data() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "\n${BLUE}Historical Data (last 10 entries):${NC}"
        tail -n 10 "$LOG_FILE"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -n|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -u|--unit)
            UNIT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -e|--email)
            ALERT_EMAIL="$2"
            shift 2
            ;;
        -l|--log)
            LOG_DATA=true
            shift
            ;;
        -g|--graph)
            GRAPH_OUTPUT=true
            shift
            ;;
        -p|--processes)
            TOP_PROCESSES=true
            shift
            ;;
        -H|--history)
            HISTORICAL=true
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
            echo "Error: Unknown option $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check dependencies
check_dependencies

# If no interface specified, list available ones and exit
if [ -z "$INTERFACE" ]; then
    list_interfaces
    exit 1
fi

# Validate interface
if [ ! -d "/sys/class/net/$INTERFACE" ]; then
    echo "Error: Interface $INTERFACE does not exist"
    list_interfaces
    exit 1
fi

# Initialize variables for speed calculation
read -r prev_rx prev_tx <<< "$(get_network_stats "$INTERFACE")"
prev_time=$(date +%s.%N)

# Show historical data if requested
[ "$HISTORICAL" = true ] && show_historical_data

# Main monitoring loop
log_message "INFO" "Starting bandwidth monitoring on interface $INTERFACE"
echo -e "${GREEN}Monitoring bandwidth on $INTERFACE (Press Ctrl+C to stop)${NC}\n"

# Variables for maximum values (for graph scaling)
max_rx=0
max_tx=0

while true; do
    # Get current stats
    read -r curr_rx curr_tx <<< "$(get_network_stats "$INTERFACE")"
    curr_time=$(date +%s.%N)
    
    # Calculate speeds
    time_diff=$(echo "$curr_time - $prev_time" | bc)
    rx_speed=$(echo "($curr_rx - $prev_rx) / $time_diff" | bc)
    tx_speed=$(echo "($curr_tx - $prev_tx) / $time_diff" | bc)
    
    # Convert to specified unit
    rx_speed_conv=$(convert_unit "$rx_speed")
    tx_speed_conv=$(convert_unit "$tx_speed")
    
    # Update maximum values
    max_rx=$(echo "if($rx_speed_conv>$max_rx) $rx_speed_conv else $max_rx" | bc)
    max_tx=$(echo "if($tx_speed_conv>$max_tx) $tx_speed_conv else $max_tx" | bc)
    
    # Format and display output
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    output=$(format_output "$timestamp" "$rx_speed_conv" "$tx_speed_conv")
    echo -e "$output"
    
    # Draw graphs if enabled
    if [ "$GRAPH_OUTPUT" = true ]; then
        echo -n "RX: "
        draw_graph "$rx_speed_conv" "$max_rx"
        echo
        echo -n "TX: "
        draw_graph "$tx_speed_conv" "$max_tx"
        echo
    fi
    
    # Check threshold
    if [ -n "$THRESHOLD" ]; then
        if (( $(echo "$rx_speed_conv > $THRESHOLD" | bc -l) )) || \
           (( $(echo "$tx_speed_conv > $THRESHOLD" | bc -l) )); then
            send_alert "Bandwidth Alert" "Bandwidth threshold exceeded on $INTERFACE"
        fi
    fi
    
    # Log data if enabled
    if [ "$LOG_DATA" = true ]; then
        echo "$output" >> "$LOG_FILE"
    fi
    
    # Show top processes if enabled
    if [ "$TOP_PROCESSES" = true ]; then
        show_top_processes
    fi
    
    # Update previous values
    prev_rx=$curr_rx
    prev_tx=$curr_tx
    prev_time=$curr_time
    
    sleep "$INTERVAL"
done
