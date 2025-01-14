#!/bin/bash

# security-updates.sh
# Security updates monitoring and management tool
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
LOG_FILE="$HOME/.security-updates-$(date +%Y%m%d).log"

# Default values
ACTION="check"
OUTPUT_FORMAT="text"
VERBOSE=false
EMAIL_ALERTS=false
EMAIL_ADDRESS=""
AUTO_UPDATE=false
SAVE_OUTPUT=false
CHECK_CVE=false
PRIORITY_ONLY=false
CUSTOM_REPO=""
EXCLUDE_PKGS=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] ACTION"
    echo
    echo "Actions:"
    echo "  check       Check for security updates"
    echo "  list        List available security updates"
    echo "  install     Install security updates"
    echo "  history     Show update history"
    echo
    echo "Options:"
    echo "  -f, --format FORMAT   Output format (text|json|csv)"
    echo "  -e, --email ADDRESS   Enable email alerts"
    echo "  -a, --auto           Enable automatic updates"
    echo "  -c, --cve            Check CVE references"
    echo "  -p, --priority       Show only high priority updates"
    echo "  -r, --repo URL       Custom repository URL"
    echo "  -x, --exclude PKGS   Exclude packages (comma-separated)"
    echo "  -o, --output FILE    Save results to file"
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
    local package="$1"
    local current_version="$2"
    local new_version="$3"
    local priority="$4"
    local cve="${5:-}"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"package":"%s","current_version":"%s","new_version":"%s","priority":"%s"%s}\n' \
                "$package" "$current_version" "$new_version" "$priority" \
                "${cve:+,\"cve\":\"$cve\"}"
            ;;
        "csv")
            printf '%s,%s,%s,%s%s\n' \
                "$package" "$current_version" "$new_version" "$priority" \
                "${cve:+,$cve}"
            ;;
        *)
            printf "%-30s %-15s %-15s %-10s%s\n" \
                "$package" "$current_version" "$new_version" "$priority" \
                "${cve:+ $cve}"
            ;;
    esac
}

# Function to detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    else
        echo "unknown"
    fi
}

# Function to check for security updates
check_updates() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        "apt")
            apt-get update >/dev/null
            apt-get --just-print upgrade | grep -i security
            ;;
        "dnf"|"yum")
            "$pkg_manager" check-update --security
            ;;
        *)
            echo "Error: Unsupported package manager"
            exit 1
            ;;
    esac
}

# Function to get package CVE information
get_cve_info() {
    local package="$1"
    local version="$2"
    
    # This is a simplified example. In practice, you'd want to query
    # the National Vulnerability Database or similar sources
    if command -v curl >/dev/null 2>&1; then
        curl -s "https://security-tracker.debian.org/tracker/source-package/$package" | \
            grep -o "CVE-[0-9]\{4\}-[0-9]\+" | head -1
    fi
}

# Function to parse security updates
parse_updates() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    # Header for text output
    if [ "$OUTPUT_FORMAT" = "text" ]; then
        printf "%-30s %-15s %-15s %-10s%s\n" \
            "Package" "Current" "New" "Priority" "$([ "$CHECK_CVE" = true ] && echo " CVE")"
        printf "%s\n" "--------------------------------------------------------------------------------"
    fi
    
    case "$pkg_manager" in
        "apt")
            while read -r line; do
                local package
                local current_version
                local new_version
                local priority
                local cve=""
                
                # Parse package information
                package=$(echo "$line" | awk '{print $2}')
                current_version=$(apt-cache policy "$package" | grep Installed | awk '{print $2}')
                new_version=$(apt-cache policy "$package" | grep Candidate | awk '{print $2}')
                priority="security"
                
                # Skip excluded packages
                [[ "$EXCLUDE_PKGS" =~ (^|,)"$package"(,|$) ]] && continue
                
                # Get CVE information if enabled
                [ "$CHECK_CVE" = true ] && cve=$(get_cve_info "$package" "$new_version")
                
                format_output "$package" "$current_version" "$new_version" "$priority" "$cve"
            done < <(check_updates)
            ;;
        "dnf"|"yum")
            while read -r line; do
                [ -z "$line" ] && continue
                
                local package
                local new_version
                local current_version
                local priority
                local cve=""
                
                # Parse package information
                package=$(echo "$line" | awk '{print $1}')
                new_version=$(echo "$line" | awk '{print $2}')
                current_version=$(rpm -q "$package" --qf '%{VERSION}-%{RELEASE}')
                priority="security"
                
                # Skip excluded packages
                [[ "$EXCLUDE_PKGS" =~ (^|,)"$package"(,|$) ]] && continue
                
                # Get CVE information if enabled
                [ "$CHECK_CVE" = true ] && cve=$(get_cve_info "$package" "$new_version")
                
                format_output "$package" "$current_version" "$new_version" "$priority" "$cve"
            done < <(check_updates)
            ;;
    esac
}

# Function to install security updates
install_updates() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    log_message "INFO" "Installing security updates"
    
    case "$pkg_manager" in
        "apt")
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
            ;;
        "dnf"|"yum")
            "$pkg_manager" -y update --security
            ;;
    esac
    
    log_message "INFO" "Security updates installed"
}

# Function to show update history
show_history() {
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        "apt")
            grep -i security /var/log/apt/history.log
            ;;
        "dnf"|"yum")
            grep -i security /var/log/yum.log
            ;;
    esac
}

# Function to send email alert
send_alert() {
    local updates="$1"
    
    if [ "$EMAIL_ALERTS" = true ] && [ -n "$EMAIL_ADDRESS" ]; then
        {
            echo "Subject: [Security Alert] Available Security Updates"
            echo "From: Security Updates <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Security updates are available for your system:"
            echo
            echo "$updates"
            echo
            echo "This is an automated message from the security updates monitoring system."
        } | sendmail -t
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL_ALERTS=true
            EMAIL_ADDRESS="$2"
            shift 2
            ;;
        -a|--auto)
            AUTO_UPDATE=true
            shift
            ;;
        -c|--cve)
            CHECK_CVE=true
            shift
            ;;
        -p|--priority)
            PRIORITY_ONLY=true
            shift
            ;;
        -r|--repo)
            CUSTOM_REPO="$2"
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_PKGS="$2"
            shift 2
            ;;
        -o|--output)
            SAVE_OUTPUT=true
            OUTPUT_FILE="$2"
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
        check|list|install|history)
            ACTION="$1"
            shift
            ;;
        *)
            echo "Error: Unknown option $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Add custom repository if specified
if [ -n "$CUSTOM_REPO" ]; then
    log_message "INFO" "Adding custom repository: $CUSTOM_REPO"
    case $(detect_package_manager) in
        "apt")
            echo "$CUSTOM_REPO" > /etc/apt/sources.list.d/custom-security.list
            apt-get update
            ;;
        "dnf"|"yum")
            yum-config-manager --add-repo "$CUSTOM_REPO"
            ;;
    esac
fi

# Main execution
log_message "INFO" "Starting security updates check"

case "$ACTION" in
    "check"|"list")
        updates=$(parse_updates)
        echo "$updates"
        
        if [ "$EMAIL_ALERTS" = true ] && [ -n "$updates" ]; then
            send_alert "$updates"
        fi
        
        if [ "$AUTO_UPDATE" = true ] && [ -n "$updates" ]; then
            install_updates
        fi
        ;;
    "install")
        install_updates
        ;;
    "history")
        show_history
        ;;
esac

log_message "INFO" "Security updates check completed"
