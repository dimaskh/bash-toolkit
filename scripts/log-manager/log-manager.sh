#!/bin/bash

# log-manager.sh
# Advanced log rotation and cleanup utility
# Author: Dima
# Date: 2025-01-14

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_MAX_SIZE="100M"
DEFAULT_RETENTION_DAYS=30
DEFAULT_COMPRESSION_TYPE="gzip"
SCRIPT_LOG="/var/log/log-manager.log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --directory DIR     Log directory to process (required)"
    echo "  -p, --pattern PATTERN   Log file pattern (e.g., '*.log') (required)"
    echo "  -s, --max-size SIZE     Maximum size for log files (default: 100M)"
    echo "  -r, --retention DAYS    Days to keep logs (default: 30)"
    echo "  -c, --compress TYPE     Compression type (gzip|bzip2|none) (default: gzip)"
    echo "  -n, --dry-run          Show what would be done without doing it"
    echo "  -h, --help             Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" | sudo tee -a "$SCRIPT_LOG"
    echo -e "${timestamp} [$level] - ${message}"
}

# Function to check if a file exceeds maximum size
check_file_size() {
    local file="$1"
    local max_size="$2"
    
    local file_size=$(stat -f %z "$file" 2>/dev/null || stat -c %s "$file")
    local max_size_bytes=$(numfmt --from=iec "$max_size")
    
    [ "$file_size" -gt "$max_size_bytes" ]
}

# Function to rotate a single log file
rotate_log() {
    local file="$1"
    local compress_type="$2"
    local dry_run="$3"
    
    local rotated_file="${file}.${TIMESTAMP}"
    
    if [ "$dry_run" = true ]; then
        echo "Would rotate $file to $rotated_file"
        return
    }
    
    # Copy the file instead of moving to avoid issues with applications
    cp "$file" "$rotated_file"
    truncate -s 0 "$file"
    
    case "$compress_type" in
        "gzip")
            gzip "$rotated_file"
            ;;
        "bzip2")
            bzip2 "$rotated_file"
            ;;
        "none")
            ;;
        *)
            log_message "ERROR" "Unknown compression type: $compress_type"
            exit 1
            ;;
    esac
    
    log_message "INFO" "Rotated $file"
}

# Function to cleanup old log files
cleanup_old_logs() {
    local directory="$1"
    local pattern="$2"
    local retention_days="$3"
    local dry_run="$4"
    
    if [ "$dry_run" = true ]; then
        echo "Would delete these files:"
        find "$directory" -name "$pattern.*" -type f -mtime +"$retention_days"
        return
    }
    
    find "$directory" -name "$pattern.*" -type f -mtime +"$retention_days" -delete
    log_message "INFO" "Cleaned up logs older than $retention_days days in $directory"
}

# Parse command line arguments
DIRECTORY=""
PATTERN=""
MAX_SIZE="$DEFAULT_MAX_SIZE"
RETENTION_DAYS="$DEFAULT_RETENTION_DAYS"
COMPRESSION_TYPE="$DEFAULT_COMPRESSION_TYPE"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            DIRECTORY="$2"
            shift 2
            ;;
        -p|--pattern)
            PATTERN="$2"
            shift 2
            ;;
        -s|--max-size)
            MAX_SIZE="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESSION_TYPE="$2"
            shift 2
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

# Validate required parameters
if [ -z "$DIRECTORY" ] || [ -z "$PATTERN" ]; then
    echo "Error: Directory and pattern are required parameters"
    print_usage
    exit 1
fi

# Validate directory exists
if [ ! -d "$DIRECTORY" ]; then
    log_message "ERROR" "Directory $DIRECTORY does not exist"
    exit 1
fi

# Main execution
log_message "INFO" "Starting log rotation with parameters: dir=$DIRECTORY, pattern=$PATTERN, max-size=$MAX_SIZE, retention=$RETENTION_DAYS days"

# Process each log file
find "$DIRECTORY" -name "$PATTERN" -type f | while read -r log_file; do
    if check_file_size "$log_file" "$MAX_SIZE"; then
        rotate_log "$log_file" "$COMPRESSION_TYPE" "$DRY_RUN"
    fi
done

# Cleanup old logs
cleanup_old_logs "$DIRECTORY" "$PATTERN" "$RETENTION_DAYS" "$DRY_RUN"

log_message "INFO" "Log rotation completed successfully"
