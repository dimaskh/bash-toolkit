#!/bin/bash

# disk-analyzer.sh
# A comprehensive disk space analyzer and cleanup utility
# Author: Dima
# Date: 2025-01-14

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/tmp/disk-analyzer-$(date +%Y%m%d).log"

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --directory DIR    Analyze specific directory (default: current directory)"
    echo "  -s, --size SIZE        Minimum file size to report (default: 100M)"
    echo "  -c, --cleanup          Perform cleanup of temporary files"
    echo "  -h, --help            Show this help message"
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${message}" | tee -a "$LOG_FILE"
}

# Function to analyze disk space
analyze_disk_space() {
    local dir="${1:-.}"
    local size="${2:-100M}"
    
    log_message "Starting disk space analysis for directory: $dir"
    
    echo -e "\n${GREEN}=== Disk Space Analysis ===${NC}"
    echo -e "\n${YELLOW}Top 10 largest directories:${NC}"
    du -h "$dir" 2>/dev/null | sort -rh | head -n 10
    
    echo -e "\n${YELLOW}Files larger than $size:${NC}"
    find "$dir" -type f -size +"$size" -exec ls -lh {} \; 2>/dev/null | sort -rh -k5
    
    echo -e "\n${YELLOW}Disk usage by file type:${NC}"
    find "$dir" -type f -exec file {} \; | awk -F: '{print $2}' | sort | uniq -c | sort -rn
}

# Function to clean temporary files
cleanup_temp_files() {
    log_message "Starting cleanup operation"
    
    echo -e "\n${GREEN}=== Cleaning Temporary Files ===${NC}"
    
    # Clean various temp directories
    local temp_dirs=("/tmp" "/var/tmp")
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${YELLOW}Cleaning $dir${NC}"
            # Find and remove files older than 7 days
            find "$dir" -type f -mtime +7 -delete 2>/dev/null || true
        fi
    done
    
    # Clean package manager caches based on the system
    if command -v apt-get &> /dev/null; then
        echo -e "${YELLOW}Cleaning APT cache${NC}"
        sudo apt-get clean
    elif command -v yum &> /dev/null; then
        echo -e "${YELLOW}Cleaning YUM cache${NC}"
        sudo yum clean all
    elif command -v dnf &> /dev/null; then
        echo -e "${YELLOW}Cleaning DNF cache${NC}"
        sudo dnf clean all
    fi
}

# Parse command line arguments
DIRECTORY="."
SIZE="100M"
DO_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            DIRECTORY="$2"
            shift 2
            ;;
        -s|--size)
            SIZE="$2"
            shift 2
            ;;
        -c|--cleanup)
            DO_CLEANUP=true
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
log_message "Script started with directory: $DIRECTORY, size: $SIZE"

if [ ! -d "$DIRECTORY" ]; then
    log_message "Error: Directory $DIRECTORY does not exist"
    echo -e "${RED}Error: Directory $DIRECTORY does not exist${NC}"
    exit 1
fi

analyze_disk_space "$DIRECTORY" "$SIZE"

if [ "$DO_CLEANUP" = true ]; then
    cleanup_temp_files
fi

log_message "Script completed successfully"
echo -e "\n${GREEN}Analysis complete. Check $LOG_FILE for detailed log.${NC}"
