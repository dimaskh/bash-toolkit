#!/bin/bash

# config-backup.sh
# Configuration files backup and versioning tool
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
LOG_FILE="$HOME/.config-backup-$(date +%Y%m%d).log"

# Default values
CONFIG_DIRS=()
BACKUP_DIR=""
EXCLUDE_PATTERNS=()
COMPRESSION="gzip"
RETENTION_DAYS=30
VERBOSE=false
DRY_RUN=false
VERIFY=false
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
VERSION_CONTROL=false
GIT_REPO=""
MAX_VERSIONS=0
ENCRYPTION=false
ENCRYPTION_KEY=""

# Common configuration directories
DEFAULT_CONFIG_DIRS=(
    "/etc"
    "/usr/local/etc"
    "$HOME/.config"
)

# Common exclude patterns
DEFAULT_EXCLUDE_PATTERNS=(
    "*.log"
    "*.pid"
    "*.sock"
    "*.swp"
    "*~"
    ".git"
    "cache"
    "tmp"
)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] BACKUP_DIR [CONFIG_DIRS...]"
    echo
    echo "Options:"
    echo "  -e, --exclude PATTERN Exclude pattern"
    echo "  -c, --compression ALG Compression (gzip|bzip2|xz)"
    echo "  -r, --retention DAYS  Retention period in days"
    echo "  -m, --max NUM        Maximum versions to keep"
    echo "  -g, --git REPO       Enable Git version control"
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

# Function to get file size
get_file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file"
}

# Function to create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$timestamp"
    local exclude_opts=""
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Build exclude options
    for pattern in "${EXCLUDE_PATTERNS[@]}" "${DEFAULT_EXCLUDE_PATTERNS[@]}"; do
        exclude_opts+=" --exclude='$pattern'"
    done
    
    # Copy configuration files
    for dir in "${CONFIG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local target_dir="$backup_path$(dirname "$dir")"
            mkdir -p "$target_dir"
            
            if [ "$DRY_RUN" = true ]; then
                eval "rsync -av --dry-run $exclude_opts \"$dir/\" \"$target_dir/\""
            else
                eval "rsync -av $exclude_opts \"$dir/\" \"$target_dir/\""
            fi
        fi
    done
    
    if [ "$DRY_RUN" = false ]; then
        # Compress backup
        local archive_file
        case "$COMPRESSION" in
            "gzip")
                archive_file="$BACKUP_DIR/config_$timestamp.tar.gz"
                tar -czf "$archive_file" -C "$BACKUP_DIR" "$timestamp"
                ;;
            "bzip2")
                archive_file="$BACKUP_DIR/config_$timestamp.tar.bz2"
                tar -cjf "$archive_file" -C "$BACKUP_DIR" "$timestamp"
                ;;
            "xz")
                archive_file="$BACKUP_DIR/config_$timestamp.tar.xz"
                tar -cJf "$archive_file" -C "$BACKUP_DIR" "$timestamp"
                ;;
        esac
        
        # Encrypt if enabled
        if [ "$ENCRYPTION" = true ] && [ -n "$ENCRYPTION_KEY" ]; then
            openssl enc -aes-256-cbc -salt -in "$archive_file" \
                -out "${archive_file}.enc" -k "$ENCRYPTION_KEY"
            rm "$archive_file"
            archive_file="${archive_file}.enc"
        fi
        
        # Verify backup if requested
        [ "$VERIFY" = true ] && verify_backup "$archive_file"
        
        # Cleanup temporary directory
        rm -rf "$backup_path"
        
        echo "$archive_file"
    fi
}

# Function to verify backup
verify_backup() {
    local backup_file="$1"
    local verify_path="/tmp/verify_backup"
    
    mkdir -p "$verify_path"
    
    # Extract and verify
    if [ "$ENCRYPTION" = true ]; then
        openssl enc -aes-256-cbc -d -in "$backup_file" \
            -out "${backup_file%.enc}" -k "$ENCRYPTION_KEY"
        backup_file="${backup_file%.enc}"
    fi
    
    case "$COMPRESSION" in
        "gzip")
            tar -xzf "$backup_file" -C "$verify_path"
            ;;
        "bzip2")
            tar -xjf "$backup_file" -C "$verify_path"
            ;;
        "xz")
            tar -xJf "$backup_file" -C "$verify_path"
            ;;
    esac
    
    # Compare directories
    local success=true
    for dir in "${CONFIG_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            if ! diff -r "$dir" "$verify_path$dir" >/dev/null; then
                log_message "ERROR" "Verification failed for $dir"
                success=false
            fi
        fi
    done
    
    # Cleanup
    rm -rf "$verify_path"
    
    if [ "$success" = true ]; then
        log_message "INFO" "Backup verification successful"
    else
        log_message "ERROR" "Backup verification failed"
        exit 1
    fi
}

# Function to initialize Git repository
init_git_repo() {
    local repo_dir="$1"
    
    if [ ! -d "$repo_dir/.git" ]; then
        git init "$repo_dir"
        echo "*.log" > "$repo_dir/.gitignore"
        echo "*.tmp" >> "$repo_dir/.gitignore"
        echo "*.swp" >> "$repo_dir/.gitignore"
        git -C "$repo_dir" add .gitignore
        git -C "$repo_dir" commit -m "Initial commit"
    fi
    
    if [ -n "$GIT_REPO" ]; then
        git -C "$repo_dir" remote add origin "$GIT_REPO"
    fi
}

# Function to commit changes to Git
commit_to_git() {
    local repo_dir="$1"
    local message="$2"
    
    git -C "$repo_dir" add .
    git -C "$repo_dir" commit -m "$message"
    
    if [ -n "$GIT_REPO" ]; then
        git -C "$repo_dir" push origin master
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    local backup_dir="$1"
    
    # Remove old backups based on retention period
    if [ "$RETENTION_DAYS" -gt 0 ]; then
        find "$backup_dir" -name "config_*.tar.*" -type f -mtime +"$RETENTION_DAYS" -delete
    fi
    
    # Remove excess versions based on maximum count
    if [ "$MAX_VERSIONS" -gt 0 ]; then
        local count
        count=$(find "$backup_dir" -name "config_*.tar.*" -type f | wc -l)
        if [ "$count" -gt "$MAX_VERSIONS" ]; then
            local excess=$((count - MAX_VERSIONS))
            find "$backup_dir" -name "config_*.tar.*" -type f -printf "%T@ %p\n" | \
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
            echo "Subject: [Config Backup] $status - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: Config Backup <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Backup Status: $status"
            echo
            echo "Details:"
            echo "$details"
            echo
            echo "This is an automated message from the configuration backup system."
        } | sendmail -t
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--exclude)
            EXCLUDE_PATTERNS+=("$2")
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
            MAX_VERSIONS="$2"
            shift 2
            ;;
        -g|--git)
            VERSION_CONTROL=true
            GIT_REPO="$2"
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
            if [ -z "$BACKUP_DIR" ]; then
                BACKUP_DIR="$1"
            else
                CONFIG_DIRS+=("$1")
            fi
            shift
            ;;
    esac
done

# Use default config directories if none specified
if [ ${#CONFIG_DIRS[@]} -eq 0 ]; then
    CONFIG_DIRS=("${DEFAULT_CONFIG_DIRS[@]}")
fi

# Validate backup directory
if [ -z "$BACKUP_DIR" ]; then
    echo "Error: Backup directory is required"
    print_usage
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Initialize Git repository if enabled
if [ "$VERSION_CONTROL" = true ]; then
    init_git_repo "$BACKUP_DIR"
fi

# Main execution
log_message "INFO" "Starting configuration backup"

# Create backup
backup_start=$(date +%s)
backup_file=$(create_backup)
backup_end=$(date +%s)
backup_duration=$((backup_end - backup_start))

if [ "$DRY_RUN" = false ]; then
    # Commit to Git if enabled
    if [ "$VERSION_CONTROL" = true ]; then
        commit_to_git "$BACKUP_DIR" "Backup $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # Cleanup old backups
    cleanup_old_backups "$BACKUP_DIR"
    
    # Calculate backup size
    backup_size=$(get_file_size "$backup_file")
    
    # Send notification
    details="Duration: $backup_duration seconds
Size: $(numfmt --to=iec-i --suffix=B $backup_size)
File: $backup_file
Directories:
$(printf '%s\n' "${CONFIG_DIRS[@]}")"
    
    send_notification "Backup Complete" "$details"
fi

log_message "INFO" "Configuration backup completed"
echo -e "\n${GREEN}Backup complete. See $LOG_FILE for detailed log.${NC}"
