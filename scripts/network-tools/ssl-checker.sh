#!/bin/bash

# ssl-checker.sh
# SSL certificate monitoring and analysis script
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
LOG_FILE="$HOME/.ssl-checker-$(date +%Y%m%d).log"

# Default values
DOMAIN=""
PORT=443
DAYS_WARNING=30
OUTPUT_FORMAT="text"
CHECK_CHAIN=false
CHECK_PROTOCOLS=false
CHECK_CIPHERS=false
ALERT_EMAIL=""
VERBOSE=false
BATCH_MODE=false
SAVE_CERT=false
CHECK_CRL=false
CHECK_OCSP=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] DOMAIN"
    echo
    echo "Options:"
    echo "  -p, --port PORT        Port number (default: 443)"
    echo "  -w, --warning DAYS     Days before expiry warning (default: 30)"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  -c, --chain           Check certificate chain"
    echo "  -P, --protocols       Check supported protocols"
    echo "  -C, --ciphers         Check supported ciphers"
    echo "  -e, --email ADDRESS    Email for alerts"
    echo "  -s, --save            Save certificate to file"
    echo "  -r, --crl             Check Certificate Revocation List"
    echo "  -o, --ocsp            Check OCSP status"
    echo "  -b, --batch FILE      Batch process domains from file"
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
    local deps=("openssl" "curl" "jq" "bc")
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
    local domain="$1"
    local expiry_date="$2"
    local days_left="$3"
    local issuer="$4"
    local subject="$5"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"domain":"%s","expiry":"%s","days_left":%d,"issuer":"%s","subject":"%s"}\n' \
                "$domain" "$expiry_date" "$days_left" "$issuer" "$subject"
            ;;
        "csv")
            printf '%s,%s,%d,%s,%s\n' "$domain" "$expiry_date" "$days_left" "$issuer" "$subject"
            ;;
        *)
            printf "Domain: %s\nExpiry: %s\nDays Left: %d\nIssuer: %s\nSubject: %s\n" \
                "$domain" "$expiry_date" "$days_left" "$issuer" "$subject"
            ;;
    esac
}

# Function to check certificate expiry
check_expiry() {
    local domain="$1"
    local port="$2"
    
    # Get certificate information
    local cert_info
    cert_info=$(echo | openssl s_client -connect "${domain}:${port}" -servername "$domain" 2>/dev/null | openssl x509 -noout -enddate -issuer -subject)
    
    # Parse certificate information
    local expiry_date
    expiry_date=$(echo "$cert_info" | grep "notAfter=" | cut -d= -f2)
    local expiry_epoch
    expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch
    current_epoch=$(date +%s)
    local days_left
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    local issuer
    issuer=$(echo "$cert_info" | grep "issuer=" | cut -d= -f2-)
    local subject
    subject=$(echo "$cert_info" | grep "subject=" | cut -d= -f2-)
    
    # Format and return results
    format_output "$domain" "$expiry_date" "$days_left" "$issuer" "$subject"
    
    # Check expiry warning
    if [ "$days_left" -le "$DAYS_WARNING" ]; then
        send_alert "SSL Certificate Expiry Warning" "Certificate for $domain will expire in $days_left days"
        return 1
    fi
    
    return 0
}

# Function to check certificate chain
check_certificate_chain() {
    local domain="$1"
    local port="$2"
    
    echo -e "\n${BLUE}Certificate Chain:${NC}"
    openssl s_client -connect "${domain}:${port}" -servername "$domain" \
        -showcerts 2>/dev/null | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/'
}

# Function to check supported protocols
check_supported_protocols() {
    local domain="$1"
    local port="$2"
    local protocols=("ssl2" "ssl3" "tls1" "tls1_1" "tls1_2" "tls1_3")
    
    echo -e "\n${BLUE}Supported Protocols:${NC}"
    for protocol in "${protocols[@]}"; do
        if openssl s_client -connect "${domain}:${port}" -servername "$domain" \
            "-${protocol}" 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            echo -e "${GREEN}✓ ${protocol}${NC}"
        else
            echo -e "${RED}✗ ${protocol}${NC}"
        fi
    done
}

# Function to check supported ciphers
check_supported_ciphers() {
    local domain="$1"
    local port="$2"
    
    echo -e "\n${BLUE}Supported Ciphers:${NC}"
    openssl ciphers -v | while read -r cipher ; do
        if openssl s_client -connect "${domain}:${port}" -servername "$domain" \
            -cipher "$cipher" 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            echo -e "${GREEN}✓ $cipher${NC}"
        fi
    done
}

# Function to save certificate
save_certificate() {
    local domain="$1"
    local port="$2"
    local filename="${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d).pem"
    
    echo | openssl s_client -connect "${domain}:${port}" -servername "$domain" 2>/dev/null \
        | openssl x509 -outform PEM > "$filename"
    
    echo -e "\n${GREEN}Certificate saved to $filename${NC}"
}

# Function to check CRL
check_crl_status() {
    local domain="$1"
    local port="$2"
    
    echo -e "\n${BLUE}CRL Status:${NC}"
    openssl s_client -connect "${domain}:${port}" -servername "$domain" 2>/dev/null \
        | openssl x509 -noout -text | grep -A 2 "CRL Distribution Points"
}

# Function to check OCSP
check_ocsp_status() {
    local domain="$1"
    local port="$2"
    
    echo -e "\n${BLUE}OCSP Status:${NC}"
    local ocsp_url
    ocsp_url=$(openssl x509 -in <(openssl s_client -connect "${domain}:${port}" \
        -servername "$domain" 2>/dev/null) -noout -ocsp_uri)
    
    if [ -n "$ocsp_url" ]; then
        openssl ocsp -issuer <(openssl s_client -connect "${domain}:${port}" \
            -servername "$domain" 2>/dev/null | openssl x509) \
            -cert <(openssl s_client -connect "${domain}:${port}" \
            -servername "$domain" 2>/dev/null | openssl x509) \
            -url "$ocsp_url" -text
    else
        echo "No OCSP URL found"
    fi
}

# Function to process single domain
process_domain() {
    local domain="$1"
    local port="$2"
    
    log_message "INFO" "Checking SSL certificate for $domain:$port"
    
    # Check basic certificate information
    if ! check_expiry "$domain" "$port"; then
        log_message "WARNING" "Certificate expiry warning for $domain"
    fi
    
    # Additional checks based on options
    [ "$CHECK_CHAIN" = true ] && check_certificate_chain "$domain" "$port"
    [ "$CHECK_PROTOCOLS" = true ] && check_supported_protocols "$domain" "$port"
    [ "$CHECK_CIPHERS" = true ] && check_supported_ciphers "$domain" "$port"
    [ "$SAVE_CERT" = true ] && save_certificate "$domain" "$port"
    [ "$CHECK_CRL" = true ] && check_crl_status "$domain" "$port"
    [ "$CHECK_OCSP" = true ] && check_ocsp_status "$domain" "$port"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -w|--warning)
            DAYS_WARNING="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -c|--chain)
            CHECK_CHAIN=true
            shift
            ;;
        -P|--protocols)
            CHECK_PROTOCOLS=true
            shift
            ;;
        -C|--ciphers)
            CHECK_CIPHERS=true
            shift
            ;;
        -e|--email)
            ALERT_EMAIL="$2"
            shift 2
            ;;
        -s|--save)
            SAVE_CERT=true
            shift
            ;;
        -r|--crl)
            CHECK_CRL=true
            shift
            ;;
        -o|--ocsp)
            CHECK_OCSP=true
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
log_message "INFO" "Starting SSL certificate check"

if [ "$BATCH_MODE" = true ]; then
    # Process domains from file
    while IFS= read -r domain || [ -n "$domain" ]; do
        [ -z "$domain" ] && continue
        [ "${domain:0:1}" = "#" ] && continue
        process_domain "$domain" "$PORT"
        echo "---"
    done < "$DOMAIN"
else
    # Process single domain
    process_domain "$DOMAIN" "$PORT"
fi

log_message "INFO" "SSL certificate check completed"
echo -e "\n${GREEN}Check complete. See $LOG_FILE for detailed log.${NC}"
