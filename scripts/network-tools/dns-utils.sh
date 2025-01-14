#!/bin/bash

# dns-utils.sh
# Comprehensive DNS lookup and analysis utilities
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
LOG_FILE="$HOME/.dns-utils-$(date +%Y%m%d).log"

# Default values
DOMAIN=""
RECORD_TYPE="ANY"
OUTPUT_FORMAT="text"
DNS_SERVER=""
VERBOSE=false
BATCH_MODE=false
SAVE_OUTPUT=false
CHECK_ALL=false
REVERSE_LOOKUP=false
TRACE_MODE=false
ZONE_TRANSFER=false

# Common DNS servers
DNS_SERVERS=(
    "8.8.8.8"      # Google
    "8.8.4.4"      # Google
    "1.1.1.1"      # Cloudflare
    "1.0.0.1"      # Cloudflare
    "9.9.9.9"      # Quad9
)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] DOMAIN"
    echo
    echo "Options:"
    echo "  -t, --type TYPE       Record type (A|AAAA|MX|NS|TXT|SOA|ANY)"
    echo "  -s, --server DNS      Specific DNS server"
    echo "  -f, --format FORMAT   Output format (text|json|csv)"
    echo "  -o, --output FILE     Save results to file"
    echo "  -a, --all            Check all record types"
    echo "  -r, --reverse        Reverse DNS lookup"
    echo "  -T, --trace          Trace DNS resolution"
    echo "  -z, --zone           Attempt zone transfer"
    echo "  -b, --batch FILE     Batch process domains from file"
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
    local deps=("dig" "host" "nslookup" "whois")
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
    local domain="$1"
    local type="$2"
    local result="$3"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"domain":"%s","type":"%s","result":"%s"}\n' \
                "$domain" "$type" "$result"
            ;;
        "csv")
            printf '%s,%s,%s\n' "$domain" "$type" "$result"
            ;;
        *)
            printf "%-30s %-6s %s\n" "$domain" "$type" "$result"
            ;;
    esac
}

# Function to perform DNS lookup
dns_lookup() {
    local domain="$1"
    local type="$2"
    local server="$3"
    
    if [ -n "$server" ]; then
        dig "@$server" "$domain" "$type" +short
    else
        dig "$domain" "$type" +short
    fi
}

# Function to perform reverse DNS lookup
reverse_dns_lookup() {
    local ip="$1"
    host "$ip" | awk '{print $NF}'
}

# Function to trace DNS resolution
trace_dns() {
    local domain="$1"
    echo -e "\n${BLUE}DNS Resolution Trace for $domain:${NC}"
    dig +trace "$domain"
}

# Function to attempt zone transfer
try_zone_transfer() {
    local domain="$1"
    
    # Get name servers
    local nameservers
    nameservers=$(dig "$domain" NS +short)
    
    echo -e "\n${BLUE}Attempting zone transfer for $domain:${NC}"
    for ns in $nameservers; do
        echo -e "\nTrying nameserver: $ns"
        dig "@$ns" "$domain" AXFR
    done
}

# Function to check all record types
check_all_records() {
    local domain="$1"
    local server="$2"
    local record_types=("A" "AAAA" "MX" "NS" "TXT" "SOA" "CNAME" "PTR" "SRV")
    
    for type in "${record_types[@]}"; do
        local result
        result=$(dns_lookup "$domain" "$type" "$server")
        if [ -n "$result" ]; then
            format_output "$domain" "$type" "$result"
        fi
    done
}

# Function to get WHOIS information
get_whois_info() {
    local domain="$1"
    echo -e "\n${BLUE}WHOIS Information for $domain:${NC}"
    whois "$domain"
}

# Function to process single domain
process_domain() {
    local domain="$1"
    
    log_message "INFO" "Processing DNS queries for $domain"
    
    # Header for text output
    if [ "$OUTPUT_FORMAT" = "text" ]; then
        printf "%-30s %-6s %s\n" "Domain" "Type" "Result"
        printf "%s\n" "------------------------------------------------"
    fi
    
    if [ "$CHECK_ALL" = true ]; then
        check_all_records "$domain" "$DNS_SERVER"
    elif [ "$REVERSE_LOOKUP" = true ]; then
        local result
        result=$(reverse_dns_lookup "$domain")
        format_output "$domain" "PTR" "$result"
    else
        local result
        result=$(dns_lookup "$domain" "$RECORD_TYPE" "$DNS_SERVER")
        format_output "$domain" "$RECORD_TYPE" "$result"
    fi
    
    [ "$TRACE_MODE" = true ] && trace_dns "$domain"
    [ "$ZONE_TRANSFER" = true ] && try_zone_transfer "$domain"
    
    # Additional information
    if [ "$VERBOSE" = true ]; then
        get_whois_info "$domain"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            RECORD_TYPE="$2"
            shift 2
            ;;
        -s|--server)
            DNS_SERVER="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            SAVE_OUTPUT=true
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -a|--all)
            CHECK_ALL=true
            shift
            ;;
        -r|--reverse)
            REVERSE_LOOKUP=true
            shift
            ;;
        -T|--trace)
            TRACE_MODE=true
            shift
            ;;
        -z|--zone)
            ZONE_TRANSFER=true
            shift
            ;;
        -b|--batch)
            BATCH_MODE=true
            DOMAIN="$2"
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
            if [ -z "$DOMAIN" ]; then
                DOMAIN="$1"
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
if [ -z "$DOMAIN" ]; then
    echo "Error: No domain specified"
    print_usage
    exit 1
fi

# Main execution
log_message "INFO" "Starting DNS utilities"

if [ "$BATCH_MODE" = true ]; then
    # Process domains from file
    while IFS= read -r domain || [ -n "$domain" ]; do
        [ -z "$domain" ] && continue
        [ "${domain:0:1}" = "#" ] && continue
        process_domain "$domain"
        echo "---"
    done < "$DOMAIN"
else
    # Process single domain
    process_domain "$DOMAIN"
fi

log_message "INFO" "DNS queries completed"
echo -e "\n${GREEN}Queries complete. See $LOG_FILE for detailed log.${NC}"
