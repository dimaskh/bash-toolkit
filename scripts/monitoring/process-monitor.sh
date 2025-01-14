#!/bin/bash

# process-monitor.sh
# Process resource usage analyzer and monitor
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
THRESHOLD_CPU=50
THRESHOLD_MEM=50
LOG_FILE=""
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
ALERT_INTERVAL=300
PROCESS_PATTERN=""
PROCESS_USER=""
EXPORT_CSV=""
DAEMON_MODE=false
SHOW_THREADS=false
JSON_OUTPUT=""
TRACE_SYSCALLS=false
TRACE_FILE_OPS=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] [PROCESS_PATTERN]"
    echo
    echo "Options:"
    echo "  -i, --interval SECS    Sampling interval (default: 1)"
    echo "  -c, --count NUM        Number of samples (default: infinite)"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  --cpu-threshold PCT    CPU usage threshold"
    echo "  --mem-threshold PCT    Memory usage threshold"
    echo "  -l, --log FILE        Log file path"
    echo "  -e, --email ADDRESS    Email for alerts"
    echo "  -a, --alert-interval S Alert interval in seconds"
    echo "  -u, --user USER       Filter by user"
    echo "  -o, --output FILE      Export data to CSV"
    echo "  -j, --json FILE       Export data to JSON"
    echo "  -d, --daemon          Run in daemon mode"
    echo "  -t, --threads         Show thread information"
    echo "  -s, --syscalls        Trace system calls"
    echo "  -F, --file-ops        Trace file operations"
    echo "  -h, --help            Show this help message"
}

# Function to get process information
get_process_info() {
    local pattern="$1"
    local user="$2"
    local pids
    
    if [ -n "$user" ]; then
        pids=$(pgrep -u "$user" -f "$pattern" 2>/dev/null)
    else
        pids=$(pgrep -f "$pattern" 2>/dev/null)
    fi
    
    for pid in $pids; do
        if [ -d "/proc/$pid" ]; then
            local cmd=$(cat "/proc/$pid/cmdline" | tr '\0' ' ' | sed 's/ $//')
            local stat=$(cat "/proc/$pid/stat")
            local status=$(cat "/proc/$pid/status")
            local io="/proc/$pid/io"
            
            # Extract CPU and memory usage
            local cpu_usage=$(ps -p "$pid" -o %cpu= 2>/dev/null || echo "0")
            local mem_usage=$(ps -p "$pid" -o %mem= 2>/dev/null || echo "0")
            local rss=$(echo "$status" | awk '/VmRSS:/ {print $2}')
            local vsz=$(echo "$status" | awk '/VmSize:/ {print $2}')
            
            # Get I/O statistics if available
            local read_bytes=0
            local write_bytes=0
            if [ -r "$io" ]; then
                read_bytes=$(awk '/read_bytes:/ {print $2}' "$io")
                write_bytes=$(awk '/write_bytes:/ {print $2}' "$io")
            fi
            
            # Get thread information if requested
            local threads=""
            if [ "$SHOW_THREADS" = true ]; then
                threads=$(ps -T -p "$pid" 2>/dev/null | tail -n +2)
            fi
            
            # Format output as JSON-like string
            echo "{\"pid\":$pid,\"cmd\":\"$cmd\",\"cpu\":$cpu_usage,\"mem\":$mem_usage,\"rss\":$rss,\"vsz\":$vsz,\"read_bytes\":$read_bytes,\"write_bytes\":$write_bytes,\"threads\":\"$threads\"}"
        fi
    done
}

# Function to trace system calls
trace_syscalls() {
    local pid="$1"
    strace -p "$pid" -c 2>/dev/null &
    echo $!
}

# Function to trace file operations
trace_file_ops() {
    local pid="$1"
    lsof -p "$pid" 2>/dev/null
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
    local process_info=$2
    
    case "$OUTPUT_FORMAT" in
        "json")
            jq -n \
                --arg ts "$timestamp" \
                --argjson info "$process_info" \
                '{timestamp: $ts, process: $info}'
            ;;
        "csv")
            echo "$timestamp,$(echo "$process_info" | jq -r '[.pid,.cpu,.mem,.rss,.vsz,.read_bytes,.write_bytes] | @csv')"
            ;;
        *)
            echo "Timestamp: $timestamp"
            echo "Process Information:"
            echo "  PID: $(echo "$process_info" | jq -r '.pid')"
            echo "  Command: $(echo "$process_info" | jq -r '.cmd')"
            echo "  CPU Usage: $(echo "$process_info" | jq -r '.cpu')%"
            echo "  Memory Usage: $(echo "$process_info" | jq -r '.mem')%"
            echo "  RSS: $(format_size $(echo "$process_info" | jq -r '.rss'))"
            echo "  VSZ: $(format_size $(echo "$process_info" | jq -r '.vsz'))"
            echo "  I/O Read: $(format_size $(echo "$process_info" | jq -r '.read_bytes'))"
            echo "  I/O Write: $(format_size $(echo "$process_info" | jq -r '.write_bytes'))"
            
            if [ "$SHOW_THREADS" = true ] && [ -n "$(echo "$process_info" | jq -r '.threads')" ]; then
                echo "Threads:"
                echo "$(echo "$process_info" | jq -r '.threads')"
            fi
            echo "-------------------"
            ;;
    esac
}

# Function to check thresholds and send alerts
check_thresholds() {
    local process_info=$1
    local last_alert_time=$2
    local current_time=$3
    
    if [ "$EMAIL_NOTIFY" = true ] && [ $((current_time - last_alert_time)) -ge "$ALERT_INTERVAL" ]; then
        local cpu_usage=$(echo "$process_info" | jq -r '.cpu')
        local mem_usage=$(echo "$process_info" | jq -r '.mem')
        
        if (( $(echo "$cpu_usage >= $THRESHOLD_CPU" | bc -l) )) || \
           (( $(echo "$mem_usage >= $THRESHOLD_MEM" | bc -l) )); then
            send_alert "WARNING" "Process resource usage is high: CPU ${cpu_usage}%, Memory ${mem_usage}%"
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
            echo "Subject: [Process Monitor] $level Alert - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: Process Monitor <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Process Monitor Alert"
            echo "Level: $level"
            echo "Message: $message"
            echo
            echo "Process Details:"
            ps -p $(echo "$process_info" | jq -r '.pid') -o pid,ppid,user,%cpu,%mem,vsz,rss,tt,stat,start,time,command
            echo
            echo "This is an automated message from the process monitoring system."
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
        --cpu-threshold)
            THRESHOLD_CPU="$2"
            shift 2
            ;;
        --mem-threshold)
            THRESHOLD_MEM="$2"
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
        -u|--user)
            PROCESS_USER="$2"
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
        -t|--threads)
            SHOW_THREADS=true
            shift
            ;;
        -s|--syscalls)
            TRACE_SYSCALLS=true
            shift
            ;;
        -F|--file-ops)
            TRACE_FILE_OPS=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$PROCESS_PATTERN" ]; then
                PROCESS_PATTERN="$1"
            else
                echo "Error: Unknown option $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Initialize CSV header if needed
if [ -n "$EXPORT_CSV" ]; then
    echo "timestamp,pid,cpu,mem,rss,vsz,read_bytes,write_bytes" > "$EXPORT_CSV"
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
strace_pid=""

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get process information
    while IFS= read -r process_info; do
        if [ -n "$process_info" ]; then
            # Start system call tracing if requested
            if [ "$TRACE_SYSCALLS" = true ] && [ -z "$strace_pid" ]; then
                strace_pid=$(trace_syscalls "$(echo "$process_info" | jq -r '.pid')")
            fi
            
            # Show file operations if requested
            if [ "$TRACE_FILE_OPS" = true ]; then
                echo "File Operations:"
                trace_file_ops "$(echo "$process_info" | jq -r '.pid')"
                echo "-------------------"
            fi
            
            # Format and display output
            output=$(format_output "$timestamp" "$process_info")
            echo "$output"
            
            # Export data if requested
            if [ -n "$EXPORT_CSV" ]; then
                export_data "$timestamp,$(echo "$process_info" | jq -r '[.pid,.cpu,.mem,.rss,.vsz,.read_bytes,.write_bytes] | @csv')" "csv" "$EXPORT_CSV"
            fi
            
            if [ -n "$JSON_OUTPUT" ]; then
                json_data=$(jq -n \
                    --arg ts "$timestamp" \
                    --argjson proc "$process_info" \
                    '{timestamp: $ts, process: $proc}')
                export_data "$json_data" "json" "$JSON_OUTPUT"
            fi
            
            # Log output if requested
            if [ -n "$LOG_FILE" ]; then
                echo "$output" >> "$LOG_FILE"
            fi
            
            # Check thresholds and send alerts
            last_alert_time=$(check_thresholds "$process_info" "$last_alert_time" "$(date +%s)")
        fi
    done < <(get_process_info "$PROCESS_PATTERN" "$PROCESS_USER")
    
    # Increment sample count and check if we're done
    ((sample_count++))
    if [ "$COUNT" -gt 0 ] && [ "$sample_count" -ge "$COUNT" ]; then
        break
    fi
    
    sleep "$INTERVAL"
done

# Cleanup
if [ -n "$strace_pid" ]; then
    kill "$strace_pid" 2>/dev/null || true
fi
