#!/bin/bash

# io-monitor.sh
# I/O operations monitoring and analysis tool
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
THRESHOLD_IOPS=1000
THRESHOLD_BANDWIDTH=50000000  # 50MB/s
LOG_FILE=""
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
ALERT_INTERVAL=300
DEVICE=""
EXPORT_CSV=""
DAEMON_MODE=false
SHOW_PROCESSES=true
JSON_OUTPUT=""
PROCESS_COUNT=10

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] [DEVICE]"
    echo
    echo "Options:"
    echo "  -i, --interval SECS    Sampling interval (default: 1)"
    echo "  -c, --count NUM        Number of samples (default: infinite)"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  --iops-threshold NUM   IOPS threshold"
    echo "  --bw-threshold BYTES   Bandwidth threshold (bytes/s)"
    echo "  -l, --log FILE        Log file path"
    echo "  -e, --email ADDRESS    Email for alerts"
    echo "  -a, --alert-interval S Alert interval in seconds"
    echo "  -p, --processes NUM    Top I/O processes to show"
    echo "  -o, --output FILE      Export data to CSV"
    echo "  -j, --json FILE       Export data to JSON"
    echo "  -d, --daemon          Run in daemon mode"
    echo "  --no-processes        Don't show process information"
    echo "  -h, --help            Show this help message"
}

# Function to get disk statistics
get_disk_stats() {
    local device=$1
    local stats
    
    if [ -n "$device" ]; then
        stats=$(cat "/sys/block/${device#/dev/}/stat")
    else
        stats=$(cat /proc/diskstats | grep -v "loop" | grep -v "ram")
    fi
    
    echo "$stats"
}

# Function to calculate disk metrics
calculate_metrics() {
    local prev_stats="$1"
    local curr_stats="$2"
    local interval="$3"
    
    while IFS= read -r line; do
        local dev_name=$(echo "$line" | awk '{print $3}')
        local curr_reads=$(echo "$line" | awk '{print $4}')
        local curr_read_sectors=$(echo "$line" | awk '{print $6}')
        local curr_writes=$(echo "$line" | awk '{print $8}')
        local curr_write_sectors=$(echo "$line" | awk '{print $10}')
        
        local prev_line=$(echo "$prev_stats" | grep " $dev_name ")
        if [ -n "$prev_line" ]; then
            local prev_reads=$(echo "$prev_line" | awk '{print $4}')
            local prev_read_sectors=$(echo "$prev_line" | awk '{print $6}')
            local prev_writes=$(echo "$prev_line" | awk '{print $8}')
            local prev_write_sectors=$(echo "$prev_line" | awk '{print $10}')
            
            local read_iops=$(( (curr_reads - prev_reads) / interval ))
            local write_iops=$(( (curr_writes - prev_writes) / interval ))
            local read_bw=$(( (curr_read_sectors - prev_read_sectors) * 512 / interval ))
            local write_bw=$(( (curr_write_sectors - prev_write_sectors) * 512 / interval ))
            
            echo "{\"device\":\"$dev_name\",\"read_iops\":$read_iops,\"write_iops\":$write_iops,\"read_bw\":$read_bw,\"write_bw\":$write_bw}"
        fi
    done < <(echo "$curr_stats")
}

# Function to get top I/O processes
get_top_processes() {
    local count=$1
    iotop -b -n 1 -P | head -n $((count + 1))
}

# Function to format size
format_size() {
    local size=$1
    local units=("B/s" "KB/s" "MB/s" "GB/s" "TB/s")
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
    local metrics=$2
    
    case "$OUTPUT_FORMAT" in
        "json")
            jq -n \
                --arg ts "$timestamp" \
                --argjson met "$metrics" \
                '{timestamp: $ts, metrics: $met}'
            ;;
        "csv")
            echo "$timestamp,$(echo "$metrics" | jq -r '[.device,.read_iops,.write_iops,.read_bw,.write_bw] | @csv')"
            ;;
        *)
            echo "Timestamp: $timestamp"
            echo "Device: $(echo "$metrics" | jq -r '.device')"
            echo "Read IOPS: $(echo "$metrics" | jq -r '.read_iops')"
            echo "Write IOPS: $(echo "$metrics" | jq -r '.write_iops')"
            echo "Read Bandwidth: $(format_size $(echo "$metrics" | jq -r '.read_bw'))"
            echo "Write Bandwidth: $(format_size $(echo "$metrics" | jq -r '.write_bw'))"
            echo "-------------------"
            ;;
    esac
}

# Function to check thresholds and send alerts
check_thresholds() {
    local metrics=$1
    local last_alert_time=$2
    local current_time=$3
    
    if [ "$EMAIL_NOTIFY" = true ] && [ $((current_time - last_alert_time)) -ge "$ALERT_INTERVAL" ]; then
        local total_iops=$(($(echo "$metrics" | jq -r '.read_iops') + $(echo "$metrics" | jq -r '.write_iops')))
        local total_bw=$(($(echo "$metrics" | jq -r '.read_bw') + $(echo "$metrics" | jq -r '.write_bw')))
        
        if [ "$total_iops" -ge "$THRESHOLD_IOPS" ] || [ "$total_bw" -ge "$THRESHOLD_BANDWIDTH" ]; then
            send_alert "WARNING" "I/O usage is high: ${total_iops} IOPS, $(format_size $total_bw)"
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
            echo "Subject: [I/O Monitor] $level Alert - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: I/O Monitor <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "I/O Monitor Alert"
            echo "Level: $level"
            echo "Message: $message"
            echo
            echo "System Information:"
            echo "-------------------"
            echo "Disk Statistics:"
            iostat -x 1 1
            echo
            echo "Top I/O Processes:"
            iotop -b -n 1 -P | head -n 6
            echo
            echo "This is an automated message from the I/O monitoring system."
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
        --iops-threshold)
            THRESHOLD_IOPS="$2"
            shift 2
            ;;
        --bw-threshold)
            THRESHOLD_BANDWIDTH="$2"
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
        --no-processes)
            SHOW_PROCESSES=false
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$DEVICE" ]; then
                DEVICE="$1"
            else
                echo "Error: Unknown option $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if iotop is available
if [ "$SHOW_PROCESSES" = true ] && ! command -v iotop >/dev/null; then
    echo "Warning: iotop not found. Process monitoring will be disabled."
    SHOW_PROCESSES=false
fi

# Initialize CSV header if needed
if [ -n "$EXPORT_CSV" ]; then
    echo "timestamp,device,read_iops,write_iops,read_bw,write_bw" > "$EXPORT_CSV"
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
prev_stats=$(get_disk_stats "$DEVICE")

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    sleep "$INTERVAL"
    
    curr_stats=$(get_disk_stats "$DEVICE")
    
    # Calculate metrics for each device
    while IFS= read -r metrics; do
        if [ -n "$metrics" ]; then
            # Format and display output
            output=$(format_output "$timestamp" "$metrics")
            echo "$output"
            
            # Export data if requested
            if [ -n "$EXPORT_CSV" ]; then
                export_data "$timestamp,$(echo "$metrics" | jq -r '[.device,.read_iops,.write_iops,.read_bw,.write_bw] | @csv')" "csv" "$EXPORT_CSV"
            fi
            
            if [ -n "$JSON_OUTPUT" ]; then
                json_data=$(jq -n \
                    --arg ts "$timestamp" \
                    --argjson met "$metrics" \
                    '{timestamp: $ts, metrics: $met}')
                export_data "$json_data" "json" "$JSON_OUTPUT"
            fi
            
            # Log output if requested
            if [ -n "$LOG_FILE" ]; then
                echo "$output" >> "$LOG_FILE"
            fi
            
            # Check thresholds and send alerts
            last_alert_time=$(check_thresholds "$metrics" "$last_alert_time" "$(date +%s)")
        fi
    done < <(calculate_metrics "$prev_stats" "$curr_stats" "$INTERVAL")
    
    # Show top I/O processes if requested
    if [ "$SHOW_PROCESSES" = true ] && [ "$PROCESS_COUNT" -gt 0 ]; then
        echo "Top I/O Processes:"
        get_top_processes "$PROCESS_COUNT"
        echo "-------------------"
    fi
    
    prev_stats="$curr_stats"
    
    # Increment sample count and check if we're done
    ((sample_count++))
    if [ "$COUNT" -gt 0 ] && [ "$sample_count" -ge "$COUNT" ]; then
        break
    fi
done
