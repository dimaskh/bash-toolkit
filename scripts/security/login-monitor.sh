#!/bin/bash

# login-monitor.sh
# Failed login attempts monitoring and alerting tool
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
LOG_FILE="$HOME/.login-monitor-$(date +%Y%m%d).log"

# Default values
WATCH_MODE=false
ALERT_THRESHOLD=5
TIME_WINDOW=300  # 5 minutes
EMAIL_ALERTS=false
EMAIL_ADDRESS=""
OUTPUT_FORMAT="text"
VERBOSE=false
CUSTOM_LOG=""
WHITELIST_FILE=""
BLACKLIST_FILE=""
IP_LOOKUP=false
SAVE_OUTPUT=false
DAEMON_MODE=false

# Log files to monitor
LOG_FILES=(
    "/var/log/auth.log"
    "/var/log/secure"
    "/var/log/syslog"
)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -w, --watch           Watch mode (continuous monitoring)"
    echo "  -t, --threshold NUM   Alert threshold (default: 5)"
    echo "  -T, --time SECONDS    Time window in seconds (default: 300)"
    echo "  -e, --email ADDRESS   Enable email alerts"
    echo "  -f, --format FORMAT   Output format (text|json|csv)"
    echo "  -l, --log FILE       Custom log file to monitor"
    echo "  -W, --whitelist FILE  IP whitelist file"
    echo "  -B, --blacklist FILE  IP blacklist file"
    echo "  -i, --ip-lookup      Enable IP geolocation lookup"
    echo "  -o, --output FILE    Save results to file"
    echo "  -d, --daemon         Run in daemon mode"
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

# Function to format output
format_output() {
    local timestamp="$1"
    local ip="$2"
    local user="$3"
    local service="$4"
    local location="$5"
    local count="$6"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"timestamp":"%s","ip":"%s","user":"%s","service":"%s","location":"%s","count":%d}\n' \
                "$timestamp" "$ip" "$user" "$service" "$location" "$count"
            ;;
        "csv")
            printf '%s,%s,%s,%s,%s,%d\n' \
                "$timestamp" "$ip" "$user" "$service" "$location" "$count"
            ;;
        *)
            printf "%-19s %-15s %-15s %-10s %-20s %d\n" \
                "$timestamp" "$ip" "$user" "$service" "$location" "$count"
            ;;
    esac
}

# Function to check if IP is whitelisted
is_whitelisted() {
    local ip="$1"
    [ -f "$WHITELIST_FILE" ] && grep -q "^$ip$" "$WHITELIST_FILE"
}

# Function to check if IP is blacklisted
is_blacklisted() {
    local ip="$1"
    [ -f "$BLACKLIST_FILE" ] && grep -q "^$ip$" "$BLACKLIST_FILE"
}

# Function to lookup IP location
lookup_ip() {
    local ip="$1"
    if command -v geoiplookup >/dev/null 2>&1; then
        geoiplookup "$ip" | awk -F ': ' '{print $2}'
    else
        echo "Unknown"
    fi
}

# Function to send email alert
send_alert() {
    local ip="$1"
    local count="$2"
    local details="$3"
    
    if [ "$EMAIL_ALERTS" = true ] && [ -n "$EMAIL_ADDRESS" ]; then
        {
            echo "Subject: [Security Alert] Failed Login Attempts"
            echo "From: Login Monitor <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Security Alert: Multiple failed login attempts detected"
            echo
            echo "IP Address: $ip"
            echo "Attempts: $count"
            echo "Time Window: $TIME_WINDOW seconds"
            echo
            echo "Details:"
            echo "$details"
            echo
            echo "This is an automated message from the login monitoring system."
        } | sendmail -t
    fi
}

# Function to parse log line
parse_log_line() {
    local line="$1"
    local timestamp
    local ip
    local user
    local service
    
    # Different log formats
    if echo "$line" | grep -q "Failed password"; then
        # SSH failed password
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        ip=$(echo "$line" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        user=$(echo "$line" | grep -oE "for [^ ]+ from" | cut -d' ' -f2)
        service="ssh"
    elif echo "$line" | grep -q "authentication failure"; then
        # PAM authentication failure
        timestamp=$(echo "$line" | awk '{print $1" "$2" "$3}')
        ip=$(echo "$line" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
        user=$(echo "$line" | grep -oE "user=[^ ]*" | cut -d= -f2)
        service="pam"
    fi
    
    # Output if we found all required fields
    if [ -n "$timestamp" ] && [ -n "$ip" ] && [ -n "$user" ]; then
        echo "$timestamp:$ip:$user:$service"
    fi
}

# Function to monitor logs
monitor_logs() {
    local log_files=("$@")
    declare -A attempts
    declare -A last_alert
    
    # Header for text output
    if [ "$OUTPUT_FORMAT" = "text" ]; then
        printf "%-19s %-15s %-15s %-10s %-20s %s\n" \
            "Timestamp" "IP" "User" "Service" "Location" "Count"
        printf "%s\n" "--------------------------------------------------------------------------------"
    fi
    
    # Monitor function
    monitor() {
        while read -r line; do
            local parsed
            parsed=$(parse_log_line "$line")
            [ -z "$parsed" ] && continue
            
            IFS=: read -r timestamp ip user service <<< "$parsed"
            
            # Skip whitelisted IPs
            is_whitelisted "$ip" && continue
            
            # Alert on blacklisted IPs
            if is_blacklisted "$ip"; then
                log_message "ALERT" "Blacklisted IP attempt: $ip"
                continue
            fi
            
            # Count attempts
            local current_time
            current_time=$(date +%s)
            local key="$ip:$user"
            
            # Clean old entries
            for k in "${!attempts[@]}"; do
                local attempt_time
                attempt_time=$(echo "${attempts[$k]}" | cut -d: -f1)
                if [ $((current_time - attempt_time)) -gt "$TIME_WINDOW" ]; then
                    unset "attempts[$k]"
                fi
            done
            
            # Update attempts
            if [ -n "${attempts[$key]}" ]; then
                local old_time
                local old_count
                IFS=: read -r old_time old_count <<< "${attempts[$key]}"
                attempts[$key]="$current_time:$((old_count + 1))"
            else
                attempts[$key]="$current_time:1"
            fi
            
            # Check threshold
            local count
            count=$(echo "${attempts[$key]}" | cut -d: -f2)
            
            if [ "$count" -ge "$ALERT_THRESHOLD" ]; then
                # Avoid repeated alerts
                local last_alert_time
                last_alert_time="${last_alert[$key]:-0}"
                
                if [ $((current_time - last_alert_time)) -gt "$TIME_WINDOW" ]; {
                    local location="Unknown"
                    [ "$IP_LOOKUP" = true ] && location=$(lookup_ip "$ip")
                    
                    format_output "$timestamp" "$ip" "$user" "$service" "$location" "$count"
                    
                    # Send alert
                    local details
                    details="Timestamp: $timestamp\nIP: $ip\nUser: $user\nService: $service\nLocation: $location\nCount: $count"
                    send_alert "$ip" "$count" "$details"
                    
                    last_alert[$key]="$current_time"
                }
                fi
            fi
        done
    }
    
    if [ "$WATCH_MODE" = true ]; then
        # Watch mode - monitor logs in real-time
        tail -F "${log_files[@]}" 2>/dev/null | monitor
    else
        # One-time mode - check existing logs
        cat "${log_files[@]}" 2>/dev/null | monitor
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -t|--threshold)
            ALERT_THRESHOLD="$2"
            shift 2
            ;;
        -T|--time)
            TIME_WINDOW="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL_ALERTS=true
            EMAIL_ADDRESS="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -l|--log)
            CUSTOM_LOG="$2"
            shift 2
            ;;
        -W|--whitelist)
            WHITELIST_FILE="$2"
            shift 2
            ;;
        -B|--blacklist)
            BLACKLIST_FILE="$2"
            shift 2
            ;;
        -i|--ip-lookup)
            IP_LOOKUP=true
            shift
            ;;
        -o|--output)
            SAVE_OUTPUT=true
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -d|--daemon)
            DAEMON_MODE=true
            WATCH_MODE=true
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

# Check if running as root for log access
if [ "$(id -u)" -ne 0 ]; then
    echo "Warning: Some log files may not be accessible without root privileges"
fi

# Use custom log if specified
if [ -n "$CUSTOM_LOG" ]; then
    LOG_FILES=("$CUSTOM_LOG")
fi

# Main execution
log_message "INFO" "Starting login monitor"

if [ "$DAEMON_MODE" = true ]; then
    # Run in background
    nohup "$0" --watch ${VERBOSE:+--verbose} \
        ${EMAIL_ALERTS:+--email "$EMAIL_ADDRESS"} \
        ${IP_LOOKUP:+--ip-lookup} \
        ${WHITELIST_FILE:+--whitelist "$WHITELIST_FILE"} \
        ${BLACKLIST_FILE:+--blacklist "$BLACKLIST_FILE"} \
        > /dev/null 2>&1 &
    
    echo "Login monitor started in daemon mode (PID: $!)"
else
    # Run in foreground
    monitor_logs "${LOG_FILES[@]}"
fi

log_message "INFO" "Login monitor completed"
