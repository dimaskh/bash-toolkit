#!/bin/bash

# incremental-backup.sh
# Incremental backup system with versioning and compression
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
LOG_FILE="$HOME/.incremental-backup-$(date +%Y%m%d).log"

# Default values
SOURCE_DIR=""
BACKUP_DIR=""
EXCLUDE_FILE=""
COMPRESSION="gzip"
RETENTION_DAYS=30
VERBOSE=false
DRY_RUN=false
VERIFY=false
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
SNAPSHOT_DIR=""
MAX_BACKUPS=0
ENCRYPTION=false
ENCRYPTION_KEY=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] SOURCE_DIR BACKUP_DIR"
    echo
    echo "Options:"
    echo "  -e, --exclude FILE    Exclude patterns file"
    echo "  -c, --compression ALG Compression (gzip|bzip2|xz)"
    echo "  -r, --retention DAYS  Retention period in days"
    echo "  -m, --max NUM        Maximum number of backups"
    echo "  -s, --snapshot DIR   Snapshot directory"
    echo "  --encrypt KEY        Enable encryption with key"
    echo "  --email ADDRESS      Enable email notifications"
    echo "  --verify            Verify backup integrity"
    echo "  --dry-run           Show what would be done"
    echo "  -v, --verbose       Verbose output"
    echo "  -h, --help          Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" >> "$LOG_FILE"
    [ "$VERBOSE" = true ] && echo -e "[$level] ${message}"
}

# Function to calculate directory size
get_dir_size() {
    local dir="$1"
    du -sb "$dir" | cut -f1
}

# Function to create snapshot
create_snapshot() {
    local source="$1"
    local snapshot="$2"
    
    if [ -d "$snapshot" ]; then
        cp -al "$snapshot" "${snapshot}.old"
    fi
    
    mkdir -p "$snapshot"
    rsync -a --delete "$source/" "$snapshot/"
    
    if [ -d "${snapshot}.old" ]; then
        rm -rf "${snapshot}.old"
    fi
}

# Function to create incremental backup
create_backup() {
    local source="$1"
    local dest="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$dest/$timestamp"
    local exclude_opts=""
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Add exclude patterns
    if [ -f "$EXCLUDE_FILE" ]; then
        exclude_opts="--exclude-from=$EXCLUDE_FILE"
    fi
    
    # Create backup
    if [ "$DRY_RUN" = true ]; then
        rsync -av --dry-run $exclude_opts "$source/" "$backup_path/"
    else
        rsync -av $exclude_opts "$source/" "$backup_path/"
        
        # Compress backup
        case "$COMPRESSION" in
            "gzip")
                tar -czf "$backup_path.tar.gz" -C "$dest" "$timestamp"
                ;;
            "bzip2")
                tar -cjf "$backup_path.tar.bz2" -C "$dest" "$timestamp"
                ;;
            "xz")
                tar -cJf "$backup_path.tar.xz" -C "$dest" "$timestamp"
                ;;
        esac
        
        # Encrypt if enabled
        if [ "$ENCRYPTION" = true ] && [ -n "$ENCRYPTION_KEY" ]; then
            openssl enc -aes-256-cbc -salt -in "$backup_path.tar.$COMPRESSION" \
                -out "$backup_path.tar.$COMPRESSION.enc" -k "$ENCRYPTION_KEY"
            rm "$backup_path.tar.$COMPRESSION"
        fi
        
        # Verify backup if requested
        if [ "$VERIFY" = true ]; then
            verify_backup "$backup_path"
        fi
        
        # Cleanup temporary directory
        rm -rf "$backup_path"
    fi
}

# Function to verify backup
verify_backup() {
    local backup_path="$1"
    local verify_path="/tmp/verify_backup"
    
    mkdir -p "$verify_path"
    
    # Extract and verify
    if [ "$ENCRYPTION" = true ]; then
        openssl enc -aes-256-cbc -d -in "$backup_path.tar.$COMPRESSION.enc" \
            -out "$backup_path.tar.$COMPRESSION" -k "$ENCRYPTION_KEY"
    fi
    
    case "$COMPRESSION" in
        "gzip")
            tar -xzf "$backup_path.tar.gz" -C "$verify_path"
            ;;
        "bzip2")
            tar -xjf "$backup_path.tar.bz2" -C "$verify_path"
            ;;
        "xz")
            tar -xJf "$backup_path.tar.xz" -C "$verify_path"
            ;;
    esac
    
    # Compare directories
    if diff -r "$SOURCE_DIR" "$verify_path" >/dev/null; then
        log_message "INFO" "Backup verification successful"
    else
        log_message "ERROR" "Backup verification failed"
        exit 1
    fi
    
    # Cleanup
    rm -rf "$verify_path"
}

# Function to cleanup old backups
cleanup_old_backups() {
    local backup_dir="$1"
    
    # Remove old backups based on retention period
    if [ "$RETENTION_DAYS" -gt 0 ]; then
        find "$backup_dir" -name "*.tar.*" -type f -mtime +"$RETENTION_DAYS" -delete
    fi
    
    # Remove excess backups based on maximum count
    if [ "$MAX_BACKUPS" -gt 0 ]; then
        local count
        count=$(find "$backup_dir" -name "*.tar.*" -type f | wc -l)
        if [ "$count" -gt "$MAX_BACKUPS" ]; then
            local excess=$((count - MAX_BACKUPS))
            find "$backup_dir" -name "*.tar.*" -type f -printf "%T@ %p\n" | \
                sort -n | head -n "$excess" | cut -d' ' -f2- | xargs rm -f
        fi
    fi
}

# Function to send email notification
send_notification() {
    local status="$1"
    local details="$2"
    
    if [ "$EMAIL_NOTIFY" = true ] && [ -n "$EMAIL_ADDRESS" ]; then
        {
            echo "Subject: [Backup] $status - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: Backup System <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Backup Status: $status"
            echo
            echo "Details:"
            echo "$details"
            echo
            echo "This is an automated message from the backup system."
        } | sendmail -t
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--exclude)
            EXCLUDE_FILE="$2"
            shift 2
            ;;
        -c|--compression)
            COMPRESSION="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -m|--max)
            MAX_BACKUPS="$2"
            shift 2
            ;;
        -s|--snapshot)
            SNAPSHOT_DIR="$2"
            shift 2
            ;;
        --encrypt)
            ENCRYPTION=true
            ENCRYPTION_KEY="$2"
            shift 2
            ;;
        --email)
            EMAIL_NOTIFY=true
            EMAIL_ADDRESS="$2"
            shift 2
            ;;
        --verify)
            VERIFY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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
            if [ -z "$SOURCE_DIR" ]; then
                SOURCE_DIR="$1"
            elif [ -z "$BACKUP_DIR" ]; then
                BACKUP_DIR="$1"
            else
                echo "Error: Unknown option $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$SOURCE_DIR" ] || [ -z "$BACKUP_DIR" ]; then
    echo "Error: Source and backup directories are required"
    print_usage
    exit 1
fi

# Validate source directory
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Main execution
log_message "INFO" "Starting incremental backup"

# Calculate initial size
initial_size=$(get_dir_size "$SOURCE_DIR")
log_message "INFO" "Initial size: $(numfmt --to=iec-i --suffix=B $initial_size)"

# Create snapshot if enabled
if [ -n "$SNAPSHOT_DIR" ]; then
    log_message "INFO" "Creating snapshot"
    create_snapshot "$SOURCE_DIR" "$SNAPSHOT_DIR"
fi

# Create backup
backup_start=$(date +%s)
create_backup "$SOURCE_DIR" "$BACKUP_DIR"
backup_end=$(date +%s)
backup_duration=$((backup_end - backup_start))

# Cleanup old backups
cleanup_old_backups "$BACKUP_DIR"

# Calculate final size
final_size=$(get_dir_size "$BACKUP_DIR")
log_message "INFO" "Final size: $(numfmt --to=iec-i --suffix=B $final_size)"

# Send notification
if [ "$DRY_RUN" = false ]; then
    details="Source: $SOURCE_DIR
Destination: $BACKUP_DIR
Duration: $backup_duration seconds
Initial Size: $(numfmt --to=iec-i --suffix=B $initial_size)
Final Size: $(numfmt --to=iec-i --suffix=B $final_size)"
    
    send_notification "Backup Complete" "$details"
fi

log_message "INFO" "Incremental backup completed"
echo -e "\n${GREEN}Backup complete. See $LOG_FILE for detailed log.${NC}"
