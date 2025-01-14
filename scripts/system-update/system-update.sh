#!/bin/bash

# system-update.sh
# Universal system update script for various Linux distributions
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
LOG_FILE="/var/log/system-update-$(date +%Y%m%d).log"

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -y, --yes             Automatic yes to prompts"
    echo "  -s, --security-only   Only install security updates"
    echo "  -b, --backup          Create system snapshot before updating"
    echo "  -n, --dry-run         Show what would be updated without installing"
    echo "  -h, --help            Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" | sudo tee -a "$LOG_FILE"
    echo -e "[$level] ${message}"
}

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Function to create system snapshot
create_snapshot() {
    log_message "INFO" "Creating system snapshot before updates"
    
    # Check if Timeshift is installed
    if command -v timeshift &> /dev/null; then
        sudo timeshift --create --comments "Before system update $(date +%Y%m%d)"
    elif command -v snapper &> /dev/null; then
        sudo snapper create --type pre --cleanup-algorithm number --print-number \
            --description "Before system update $(date +%Y%m%d)"
    else
        log_message "WARNING" "No snapshot tool found (timeshift/snapper). Skipping backup."
        return 1
    fi
}

# Function to update package lists
update_package_lists() {
    local distro="$1"
    log_message "INFO" "Updating package lists"
    
    case "$distro" in
        "ubuntu"|"debian")
            sudo apt-get update
            ;;
        "fedora")
            sudo dnf check-update || true  # dnf returns 100 if updates are available
            ;;
        "centos"|"rhel")
            sudo yum check-update || true  # yum returns 100 if updates are available
            ;;
        "arch")
            sudo pacman -Sy
            ;;
        *)
            log_message "ERROR" "Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

# Function to perform system upgrade
perform_upgrade() {
    local distro="$1"
    local security_only="$2"
    local auto_yes="$3"
    local dry_run="$4"
    
    log_message "INFO" "Starting system upgrade"
    
    local yes_flag=""
    [ "$auto_yes" = true ] && yes_flag="-y"
    
    case "$distro" in
        "ubuntu"|"debian")
            if [ "$security_only" = true ]; then
                if [ "$dry_run" = true ]; then
                    sudo apt-get --simulate dist-upgrade -t $(lsb_release -cs)-security
                else
                    sudo apt-get $yes_flag dist-upgrade -t $(lsb_release -cs)-security
                fi
            else
                if [ "$dry_run" = true ]; then
                    sudo apt-get --simulate upgrade
                else
                    sudo apt-get $yes_flag upgrade
                fi
            fi
            ;;
        "fedora")
            if [ "$security_only" = true ]; then
                if [ "$dry_run" = true ]; then
                    sudo dnf updateinfo --security
                else
                    sudo dnf $yes_flag update --security
                fi
            else
                if [ "$dry_run" = true ]; then
                    sudo dnf check-update
                else
                    sudo dnf $yes_flag upgrade
                fi
            fi
            ;;
        "centos"|"rhel")
            if [ "$security_only" = true ]; then
                if [ "$dry_run" = true ]; then
                    sudo yum updateinfo --security
                else
                    sudo yum $yes_flag update --security
                fi
            else
                if [ "$dry_run" = true ]; then
                    sudo yum check-update
                else
                    sudo yum $yes_flag update
                fi
            fi
            ;;
        "arch")
            if [ "$dry_run" = true ]; then
                sudo pacman -Qu
            else
                sudo pacman --noconfirm -Su
            fi
            ;;
        *)
            log_message "ERROR" "Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

# Function to cleanup package cache
cleanup_package_cache() {
    local distro="$1"
    log_message "INFO" "Cleaning up package cache"
    
    case "$distro" in
        "ubuntu"|"debian")
            sudo apt-get clean
            sudo apt-get autoremove --purge -y
            ;;
        "fedora")
            sudo dnf clean all
            sudo dnf autoremove -y
            ;;
        "centos"|"rhel")
            sudo yum clean all
            sudo yum autoremove -y
            ;;
        "arch")
            sudo pacman -Sc --noconfirm
            ;;
    esac
}

# Parse command line arguments
AUTO_YES=false
SECURITY_ONLY=false
DO_BACKUP=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        -s|--security-only)
            SECURITY_ONLY=true
            shift
            ;;
        -b|--backup)
            DO_BACKUP=true
            shift
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Main execution
log_message "INFO" "Starting system update script"

# Detect distribution
DISTRO=$(detect_distro)
log_message "INFO" "Detected distribution: $DISTRO"

if [ "$DISTRO" = "unknown" ]; then
    log_message "ERROR" "Could not detect Linux distribution"
    exit 1
fi

# Create snapshot if requested
if [ "$DO_BACKUP" = true ]; then
    create_snapshot || log_message "WARNING" "Failed to create system snapshot"
fi

# Update package lists
update_package_lists "$DISTRO" || {
    log_message "ERROR" "Failed to update package lists"
    exit 1
}

# Perform system upgrade
perform_upgrade "$DISTRO" "$SECURITY_ONLY" "$AUTO_YES" "$DRY_RUN" || {
    log_message "ERROR" "System upgrade failed"
    exit 1
}

# Cleanup package cache
cleanup_package_cache "$DISTRO"

log_message "INFO" "System update completed successfully"
echo -e "\n${GREEN}Update complete. Check $LOG_FILE for detailed log.${NC}"
