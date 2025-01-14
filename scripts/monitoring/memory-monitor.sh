#!/bin/bash

# memory-monitor.sh
# Advanced memory usage monitoring and analysis tool
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

# Default values
INTERVAL=1
COUNT=0
OUTPUT_FORMAT="text"
THRESHOLD_WARNING=80
THRESHOLD_CRITICAL=90
LOG_FILE=""
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
ALERT_INTERVAL=300
PROCESS_COUNT=10
EXPORT_CSV=""
DAEMON_MODE=false
SHOW_SWAP=true
JSON_OUTPUT=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -i, --interval SECS    Sampling interval (default: 1)"
    echo "  -c, --count NUM        Number of samples (default: infinite)"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  -w, --warning PCT      Warning threshold percentage"
    echo "  -C, --critical PCT     Critical threshold percentage"
    echo "  -l, --log FILE        Log file path"
    echo "  -e, --email ADDRESS    Email for alerts"
    echo "  -a, --alert-interval S Alert interval in seconds"
    echo "  -p, --processes NUM    Top processes to show"
    echo "  -o, --output FILE      Export data to CSV"
    echo "  -j, --json FILE       Export data to JSON"
    echo "  -d, --daemon          Run in daemon mode"
    echo "  --no-swap            Don't show swap usage"
    echo "  -h, --help            Show this help message"
}

# Function to get memory usage
get_memory_usage() {
    local mem_info
    mem_info=$(free -b)
    local total
    local used
    local free
    local shared
    local buffers
    local cached
    
    # Parse memory information
    eval $(echo "$mem_info" | awk '/Mem:/ {printf "total=%d; used=%d; free=%d; shared=%d; buffers=%d; cached=%d", $2, $3, $4, $5, $6, $7}')
    
    # Calculate percentages
    local used_percent=$((used * 100 / total))
    local free_percent=$((free * 100 / total))
    local cached_percent=$((cached * 100 / total))
    local buffers_percent=$((buffers * 100 / total))
    
    # Return as JSON-like string for easy parsing
    echo "{\"total\":$total,\"used\":$used,\"free\":$free,\"shared\":$shared,\"buffers\":$buffers,\"cached\":$cached,\"used_percent\":$used_percent,\"free_percent\":$free_percent,\"cached_percent\":$cached_percent,\"buffers_percent\":$buffers_percent}"
}

# Function to get swap usage
get_swap_usage() {
    local swap_info
    swap_info=$(free -b | awk '/Swap:/ {printf "total=%d; used=%d; free=%d", $2, $3, $4}')
    eval "$swap_info"
    
    local used_percent=0
    if [ "$total" -gt 0 ]; then
        used_percent=$((used * 100 / total))
    fi
    
    echo "{\"total\":$total,\"used\":$used,\"free\":$free,\"used_percent\":$used_percent}"
}

# Function to get top memory processes
get_top_processes() {
    local count=$1
    ps -eo pid,ppid,cmd,%mem,rss,vsz --sort=-%mem | head -n $((count + 1))
}

# Function to format size
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ "$size" -ge 1024 ] && [ "$unit" -lt 4 ]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "$size${units[$unit]}"
}

# Function to format output
format_output() {
    local timestamp=$1
    local mem_usage=$2
    local swap_usage=$3
    
    case "$OUTPUT_FORMAT" in
        "json")
            jq -n \
                --arg ts "$timestamp" \
                --argjson mem "$mem_usage" \
                --argjson swap "$swap_usage" \
                '{timestamp: $ts, memory: $mem, swap: $swap}'
            ;;
        "csv")
            local mem_used_percent=$(echo "$mem_usage" | jq -r '.used_percent')
            local swap_used_percent=$(echo "$swap_usage" | jq -r '.used_percent')
            echo "$timestamp,$mem_used_percent,$swap_used_percent"
            ;;
        *)
            echo "Timestamp: $timestamp"
            echo "Memory Usage:"
            echo "  Total: $(format_size $(echo "$mem_usage" | jq -r '.total'))"
            echo "  Used:  $(format_size $(echo "$mem_usage" | jq -r '.used')) ($(echo "$mem_usage" | jq -r '.used_percent')%)"
            echo "  Free:  $(format_size $(echo "$mem_usage" | jq -r '.free')) ($(echo "$mem_usage" | jq -r '.free_percent')%)"
            echo "  Cached: $(format_size $(echo "$mem_usage" | jq -r '.cached')) ($(echo "$mem_usage" | jq -r '.cached_percent')%)"
            echo "  Buffers: $(format_size $(echo "$mem_usage" | jq -r '.buffers')) ($(echo "$mem_usage" | jq -r '.buffers_percent')%)"
            
            if [ "$SHOW_SWAP" = true ]; then
                echo "Swap Usage:"
                echo "  Total: $(format_size $(echo "$swap_usage" | jq -r '.total'))"
                echo "  Used:  $(format_size $(echo "$swap_usage" | jq -r '.used')) ($(echo "$swap_usage" | jq -r '.used_percent')%)"
                echo "  Free:  $(format_size $(echo "$swap_usage" | jq -r '.free'))"
            fi
            echo "-------------------"
            ;;
    esac
}

# Function to check thresholds and send alerts
check_thresholds() {
    local mem_usage=$1
    local swap_usage=$2
    local last_alert_time=$3
    local current_time=$4
    
    if [ "$EMAIL_NOTIFY" = true ] && [ $((current_time - last_alert_time)) -ge "$ALERT_INTERVAL" ]; then
        local mem_used_percent=$(echo "$mem_usage" | jq -r '.used_percent')
        local swap_used_percent=$(echo "$swap_usage" | jq -r '.used_percent')
        
        if (( mem_used_percent >= THRESHOLD_CRITICAL )) || (( swap_used_percent >= THRESHOLD_CRITICAL )); then
            send_alert "CRITICAL" "Memory usage is critically high: ${mem_used_percent}% (Swap: ${swap_used_percent}%)"
            return "$current_time"
        elif (( mem_used_percent >= THRESHOLD_WARNING )) || (( swap_used_percent >= THRESHOLD_WARNING )); then
            send_alert "WARNING" "Memory usage is high: ${mem_used_percent}% (Swap: ${swap_used_percent}%)"
            return "$current_time"
        fi
    fi
    return "$last_alert_time"
}

# Function to send email alerts
send_alert() {
    local level="$1"
    local message="$2"
    
    if [ "$EMAIL_NOTIFY" = true ] && [ -n "$EMAIL_ADDRESS" ]; then
        {
            echo "Subject: [Memory Monitor] $level Alert - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: Memory Monitor <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Memory Monitor Alert"
            echo "Level: $level"
            echo "Message: $message"
            echo
            echo "System Information:"
            echo "-------------------"
            echo "Memory Status:"
            free -h
            echo
            echo "Top Memory Processes:"
            ps -eo pid,ppid,cmd,%mem,rss,vsz --sort=-%mem | head -n 6
            echo
            echo "This is an automated message from the memory monitoring system."
        } | sendmail -t
    fi
}

# Function to export data
export_data() {
    local data="$1"
    local format="$2"
    local file="$3"
    
    case "$format" in
        "csv")
            echo "$data" >> "$file"
            ;;
        "json")
            if [ ! -f "$file" ]; then
                echo "[]" > "$file"
            fi
            local tmp_file=$(mktemp)
            jq --argjson new "$data" '. + [$new]' "$file" > "$tmp_file"
            mv "$tmp_file" "$file"
            ;;
    esac
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -w|--warning)
            THRESHOLD_WARNING="$2"
            shift 2
            ;;
        -C|--critical)
            THRESHOLD_CRITICAL="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL_NOTIFY=true
            EMAIL_ADDRESS="$2"
            shift 2
            ;;
        -a|--alert-interval)
            ALERT_INTERVAL="$2"
            shift 2
            ;;
        -p|--processes)
            PROCESS_COUNT="$2"
            shift 2
            ;;
        -o|--output)
            EXPORT_CSV="$2"
            shift 2
            ;;
        -j|--json)
            JSON_OUTPUT="$2"
            shift 2
            ;;
        -d|--daemon)
            DAEMON_MODE=true
            shift
            ;;
        --no-swap)
            SHOW_SWAP=false
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

# Initialize CSV header if needed
if [ -n "$EXPORT_CSV" ]; then
    echo "timestamp,memory_used_percent,swap_used_percent" > "$EXPORT_CSV"
fi

# Initialize JSON file if needed
if [ -n "$JSON_OUTPUT" ]; then
    echo "[]" > "$JSON_OUTPUT"
fi

# Run in daemon mode if requested
if [ "$DAEMON_MODE" = true ]; then
    exec 1>/dev/null
    exec 2>&1
    exec 3>&1
fi

# Main monitoring loop
sample_count=0
last_alert_time=0

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mem_usage=$(get_memory_usage)
    swap_usage=$(get_swap_usage)
    
    # Format and display output
    output=$(format_output "$timestamp" "$mem_usage" "$swap_usage")
    echo "$output"
    
    # Export data if requested
    if [ -n "$EXPORT_CSV" ]; then
        export_data "$timestamp,$(echo "$mem_usage" | jq -r '.used_percent'),$(echo "$swap_usage" | jq -r '.used_percent')" "csv" "$EXPORT_CSV"
    fi
    
    if [ -n "$JSON_OUTPUT" ]; then
        json_data=$(jq -n \
            --arg ts "$timestamp" \
            --argjson mem "$mem_usage" \
            --argjson swap "$swap_usage" \
            '{timestamp: $ts, memory: $mem, swap: $swap}')
        export_data "$json_data" "json" "$JSON_OUTPUT"
    fi
    
    # Log output if requested
    if [ -n "$LOG_FILE" ]; then
        echo "$output" >> "$LOG_FILE"
    fi
    
    # Check thresholds and send alerts
    last_alert_time=$(check_thresholds "$mem_usage" "$swap_usage" "$last_alert_time" "$(date +%s)")
    
    # Display top memory processes
    if [ "$PROCESS_COUNT" -gt 0 ]; then
        echo "Top Memory Processes:"
        get_top_processes "$PROCESS_COUNT"
        echo "-------------------"
    fi
    
    # Increment sample count and check if we're done
    ((sample_count++))
    if [ "$COUNT" -gt 0 ] && [ "$sample_count" -ge "$COUNT" ]; then
        break
    fi
    
    sleep "$INTERVAL"
done
