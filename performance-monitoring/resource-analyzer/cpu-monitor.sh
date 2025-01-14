#!/bin/bash

# cpu-monitor.sh
# Advanced CPU usage monitoring and analysis tool
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
THRESHOLD_WARNING=70
THRESHOLD_CRITICAL=90
LOG_FILE=""
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
ALERT_INTERVAL=300
PROCESS_COUNT=10
EXPORT_CSV=""
DAEMON_MODE=false
DISPLAY_CORES=false
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
    echo "  --cores              Show per-core statistics"
    echo "  -h, --help            Show this help message"
}

# Function to get CPU usage
get_cpu_usage() {
    local cpu_usage
    if [ "$DISPLAY_CORES" = true ]; then
        cpu_usage=$(top -bn1 | grep "Cpu" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100-$1}')
    else
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100-$1}')
    fi
    echo "$cpu_usage"
}

# Function to get per-core usage
get_core_usage() {
    mpstat -P ALL 1 1 | awk '/^[0-9]/ {print $2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12}'
}

# Function to get top CPU processes
get_top_processes() {
    local count=$1
    ps -eo pid,ppid,cmd,%cpu,%mem,time --sort=-%cpu | head -n $((count + 1))
}

# Function to get CPU temperature
get_cpu_temperature() {
    if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
        echo $(($(cat /sys/class/thermal/thermal_zone0/temp) / 1000))
    else
        echo "N/A"
    fi
}

# Function to get CPU frequency
get_cpu_frequency() {
    local freq
    if [ -f "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq" ]; then
        freq=$(($(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) / 1000))
        echo "${freq}MHz"
    else
        echo "N/A"
    fi
}

# Function to format output
format_output() {
    local timestamp=$1
    local cpu_usage=$2
    local temperature=$3
    local frequency=$4
    
    case "$OUTPUT_FORMAT" in
        "json")
            jq -n \
                --arg ts "$timestamp" \
                --arg cpu "$cpu_usage" \
                --arg temp "$temperature" \
                --arg freq "$frequency" \
                '{timestamp: $ts, cpu_usage: $cpu, temperature: $temp, frequency: $freq}'
            ;;
        "csv")
            echo "$timestamp,$cpu_usage,$temperature,$frequency"
            ;;
        *)
            echo "Timestamp: $timestamp"
            echo "CPU Usage: ${cpu_usage}%"
            echo "Temperature: ${temperature}°C"
            echo "Frequency: $frequency"
            echo "-------------------"
            ;;
    esac
}

# Function to check thresholds and send alerts
check_thresholds() {
    local cpu_usage=$1
    local last_alert_time=$2
    local current_time=$3
    
    if [ "$EMAIL_NOTIFY" = true ] && [ $((current_time - last_alert_time)) -ge "$ALERT_INTERVAL" ]; then
        if (( $(echo "$cpu_usage >= $THRESHOLD_CRITICAL" | bc -l) )); then
            send_alert "CRITICAL" "CPU usage is critically high: ${cpu_usage}%"
            return "$current_time"
        elif (( $(echo "$cpu_usage >= $THRESHOLD_WARNING" | bc -l) )); then
            send_alert "WARNING" "CPU usage is high: ${cpu_usage}%"
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
            echo "Subject: [CPU Monitor] $level Alert - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: CPU Monitor <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "CPU Monitor Alert"
            echo "Level: $level"
            echo "Message: $message"
            echo
            echo "System Information:"
            echo "-------------------"
            echo "Hostname: $(hostname)"
            echo "Load Average: $(uptime | awk -F'load average:' '{ print $2 }')"
            echo
            echo "Top CPU Processes:"
            ps -eo pid,ppid,cmd,%cpu,%mem,time --sort=-%cpu | head -n 6
            echo
            echo "This is an automated message from the CPU monitoring system."
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
        --cores)
            DISPLAY_CORES=true
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
    echo "timestamp,cpu_usage,temperature,frequency" > "$EXPORT_CSV"
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
    cpu_usage=$(get_cpu_usage)
    temperature=$(get_cpu_temperature)
    frequency=$(get_cpu_frequency)
    
    # Format and display output
    output=$(format_output "$timestamp" "$cpu_usage" "$temperature" "$frequency")
    echo "$output"
    
    # Export data if requested
    if [ -n "$EXPORT_CSV" ]; then
        export_data "$timestamp,$cpu_usage,$temperature,$frequency" "csv" "$EXPORT_CSV"
    fi
    
    if [ -n "$JSON_OUTPUT" ]; then
        json_data=$(echo "$output" | jq -R -s '{timestamp: input}')
        export_data "$json_data" "json" "$JSON_OUTPUT"
    fi
    
    # Log output if requested
    if [ -n "$LOG_FILE" ]; then
        echo "$output" >> "$LOG_FILE"
    fi
    
    # Check thresholds and send alerts
    last_alert_time=$(check_thresholds "$cpu_usage" "$last_alert_time" "$(date +%s)")
    
    # Display per-core statistics if requested
    if [ "$DISPLAY_CORES" = true ]; then
        echo "Per-Core Statistics:"
        get_core_usage
        echo "-------------------"
    fi
    
    # Display top CPU processes
    if [ "$PROCESS_COUNT" -gt 0 ]; then
        echo "Top CPU Processes:"
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
