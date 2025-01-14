#!/bin/bash

# restore-point.sh
# System restore point creator and manager
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
LOG_FILE="$HOME/.restore-point-$(date +%Y%m%d).log"

# Default values
RESTORE_DIR=""
ACTION=""
POINT_NAME=""
DESCRIPTION=""
INCLUDE_DIRS=()
EXCLUDE_PATTERNS=()
COMPRESSION="gzip"
RETENTION_DAYS=30
VERBOSE=false
DRY_RUN=false
VERIFY=false
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
MAX_POINTS=0
ENCRYPTION=false
ENCRYPTION_KEY=""

# Default directories to include
DEFAULT_INCLUDE_DIRS=(
    "/etc"
    "/usr/local/etc"
    "/var/lib"
    "/home"
)

# Default exclude patterns
DEFAULT_EXCLUDE_PATTERNS=(
    "/proc/*"
    "/sys/*"
    "/dev/*"
    "/run/*"
    "/tmp/*"
    "/var/tmp/*"
    "/var/cache/*"
    "/var/log/*"
    "*.log"
    "*.tmp"
    "*.pid"
    "*.sock"
    ".git"
    "node_modules"
    "__pycache__"
)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] ACTION RESTORE_DIR"
    echo
    echo "Actions:"
    echo "  create     Create a new restore point"
    echo "  list       List available restore points"
    echo "  show       Show details of a specific restore point"
    echo "  restore    Restore from a specific point"
    echo "  delete     Delete a specific restore point"
    echo "  verify     Verify integrity of a restore point"
    echo
    echo "Options:"
    echo "  -n, --name NAME      Restore point name"
    echo "  -d, --desc TEXT      Description"
    echo "  -i, --include DIR    Include directory"
    echo "  -e, --exclude PAT    Exclude pattern"
    echo "  -c, --compression ALG Compression (gzip|bzip2|xz)"
    echo "  -r, --retention DAYS  Retention period in days"
    echo "  -m, --max NUM        Maximum points to keep"
    echo "  --encrypt KEY        Enable encryption with key"
    echo "  --email ADDRESS      Enable email notifications"
    echo "  --verify            Verify restore point integrity"
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

# Function to get directory size
get_dir_size() {
    local dir="$1"
    du -sb "$dir" | cut -f1
}

# Function to create restore point
create_restore_point() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local point_dir="$RESTORE_DIR/$POINT_NAME"
    local metadata_file="$point_dir/metadata.json"
    local exclude_opts=""
    
    # Create restore point directory
    mkdir -p "$point_dir"
    
    # Build exclude options
    for pattern in "${EXCLUDE_PATTERNS[@]}" "${DEFAULT_EXCLUDE_PATTERNS[@]}"; do
        exclude_opts+=" --exclude='$pattern'"
    done
    
    # Create metadata
    cat > "$metadata_file" << EOF
{
    "name": "$POINT_NAME",
    "timestamp": "$timestamp",
    "description": "$DESCRIPTION",
    "created_by": "$(whoami)",
    "hostname": "$(hostname)",
    "included_dirs": $(printf '%s\n' "${INCLUDE_DIRS[@]}" | jq -R . | jq -s .),
    "excluded_patterns": $(printf '%s\n' "${EXCLUDE_PATTERNS[@]}" "${DEFAULT_EXCLUDE_PATTERNS[@]}" | jq -R . | jq -s .),
    "compression": "$COMPRESSION",
    "encrypted": $ENCRYPTION
}
EOF
    
    # Copy directories
    for dir in "${INCLUDE_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            local target_dir="$point_dir/data$(dirname "$dir")"
            mkdir -p "$target_dir"
            
            if [ "$DRY_RUN" = true ]; then
                eval "rsync -av --dry-run $exclude_opts \"$dir/\" \"$target_dir/\""
            else
                eval "rsync -av $exclude_opts \"$dir/\" \"$target_dir/\""
            fi
        fi
    done
    
    if [ "$DRY_RUN" = false ]; then
        # Compress restore point
        local archive_file
        case "$COMPRESSION" in
            "gzip")
                archive_file="$RESTORE_DIR/${POINT_NAME}.tar.gz"
                tar -czf "$archive_file" -C "$RESTORE_DIR" "$POINT_NAME"
                ;;
            "bzip2")
                archive_file="$RESTORE_DIR/${POINT_NAME}.tar.bz2"
                tar -cjf "$archive_file" -C "$RESTORE_DIR" "$POINT_NAME"
                ;;
            "xz")
                archive_file="$RESTORE_DIR/${POINT_NAME}.tar.xz"
                tar -cJf "$archive_file" -C "$RESTORE_DIR" "$POINT_NAME"
                ;;
        esac
        
        # Encrypt if enabled
        if [ "$ENCRYPTION" = true ] && [ -n "$ENCRYPTION_KEY" ]; then
            openssl enc -aes-256-cbc -salt -in "$archive_file" \
                -out "${archive_file}.enc" -k "$ENCRYPTION_KEY"
            rm "$archive_file"
            archive_file="${archive_file}.enc"
        fi
        
        # Verify restore point if requested
        [ "$VERIFY" = true ] && verify_restore_point "$archive_file"
        
        # Cleanup temporary directory
        rm -rf "$point_dir"
        
        echo "$archive_file"
    fi
}

# Function to list restore points
list_restore_points() {
    local format="%-30s %-20s %-20s %s\n"
    printf "$format" "NAME" "TIMESTAMP" "SIZE" "DESCRIPTION"
    echo "--------------------------------------------------------------------------------"
    
    for point in "$RESTORE_DIR"/*.tar.*; do
        if [ -f "$point" ]; then
            local name=$(basename "$point" | sed 's/\.tar\..*//')
            local metadata
            
            # Extract metadata
            if [[ "$point" == *.enc ]]; then
                metadata=$(openssl enc -aes-256-cbc -d -in "$point" -k "$ENCRYPTION_KEY" | \
                    tar -xO -f - "$name/metadata.json" 2>/dev/null)
            else
                metadata=$(tar -xO -f "$point" "$name/metadata.json" 2>/dev/null)
            fi
            
            if [ -n "$metadata" ]; then
                local timestamp=$(echo "$metadata" | jq -r '.timestamp')
                local description=$(echo "$metadata" | jq -r '.description')
                local size=$(get_dir_size "$point")
                printf "$format" "$name" "$timestamp" "$(numfmt --to=iec-i --suffix=B $size)" "$description"
            fi
        fi
    done
}

# Function to show restore point details
show_restore_point() {
    local point_file="$RESTORE_DIR/${POINT_NAME}.tar"
    local found=false
    
    for ext in gz bz2 xz enc; do
        if [ -f "${point_file}.${ext}" ]; then
            point_file="${point_file}.${ext}"
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Error: Restore point not found: $POINT_NAME"
        exit 1
    fi
    
    local metadata
    if [[ "$point_file" == *.enc ]]; then
        metadata=$(openssl enc -aes-256-cbc -d -in "$point_file" -k "$ENCRYPTION_KEY" | \
            tar -xO -f - "$POINT_NAME/metadata.json")
    else
        metadata=$(tar -xO -f "$point_file" "$POINT_NAME/metadata.json")
    fi
    
    echo "Restore Point Details:"
    echo "---------------------"
    echo "$metadata" | jq '.'
}

# Function to restore from point
restore_from_point() {
    local point_file="$RESTORE_DIR/${POINT_NAME}.tar"
    local found=false
    
    for ext in gz bz2 xz enc; do
        if [ -f "${point_file}.${ext}" ]; then
            point_file="${point_file}.${ext}"
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Error: Restore point not found: $POINT_NAME"
        exit 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "Would restore from: $point_file"
        return
    fi
    
    local temp_dir="/tmp/restore_${POINT_NAME}"
    mkdir -p "$temp_dir"
    
    # Extract restore point
    if [[ "$point_file" == *.enc ]]; then
        openssl enc -aes-256-cbc -d -in "$point_file" -k "$ENCRYPTION_KEY" | \
            tar -x -C "$temp_dir" -f -
    else
        tar -x -C "$temp_dir" -f "$point_file"
    fi
    
    # Restore files
    local data_dir="$temp_dir/$POINT_NAME/data"
    if [ -d "$data_dir" ]; then
        cp -a "$data_dir/." "/"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to delete restore point
delete_restore_point() {
    local point_file="$RESTORE_DIR/${POINT_NAME}.tar"
    local found=false
    
    for ext in gz bz2 xz enc; do
        if [ -f "${point_file}.${ext}" ]; then
            point_file="${point_file}.${ext}"
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        echo "Error: Restore point not found: $POINT_NAME"
        exit 1
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "Would delete: $point_file"
    else
        rm -f "$point_file"
        log_message "INFO" "Deleted restore point: $POINT_NAME"
    fi
}

# Function to verify restore point
verify_restore_point() {
    local point_file="$1"
    local verify_path="/tmp/verify_restore"
    
    mkdir -p "$verify_path"
    
    # Extract and verify
    if [[ "$point_file" == *.enc ]]; then
        openssl enc -aes-256-cbc -d -in "$point_file" -k "$ENCRYPTION_KEY" | \
            tar -x -C "$verify_path" -f -
    else
        tar -x -C "$verify_path" -f "$point_file"
    fi
    
    # Verify metadata
    if [ ! -f "$verify_path/$POINT_NAME/metadata.json" ]; then
        log_message "ERROR" "Metadata file not found"
        rm -rf "$verify_path"
        exit 1
    fi
    
    # Verify files
    local success=true
    local data_dir="$verify_path/$POINT_NAME/data"
    if [ -d "$data_dir" ]; then
        for dir in "${INCLUDE_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                if ! diff -r "$dir" "$data_dir$dir" >/dev/null; then
                    log_message "ERROR" "Verification failed for $dir"
                    success=false
                fi
            fi
        done
    fi
    
    # Cleanup
    rm -rf "$verify_path"
    
    if [ "$success" = true ]; then
        log_message "INFO" "Restore point verification successful"
    else
        log_message "ERROR" "Restore point verification failed"
        exit 1
    fi
}

# Function to cleanup old restore points
cleanup_old_points() {
    # Remove old points based on retention period
    if [ "$RETENTION_DAYS" -gt 0 ]; then
        find "$RESTORE_DIR" -name "*.tar.*" -type f -mtime +"$RETENTION_DAYS" -delete
    fi
    
    # Remove excess points based on maximum count
    if [ "$MAX_POINTS" -gt 0 ]; then
        local count
        count=$(find "$RESTORE_DIR" -name "*.tar.*" -type f | wc -l)
        if [ "$count" -gt "$MAX_POINTS" ]; then
            local excess=$((count - MAX_POINTS))
            find "$RESTORE_DIR" -name "*.tar.*" -type f -printf "%T@ %p\n" | \
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
            echo "Subject: [Restore Point] $status - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: Restore Point <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Restore Point Status: $status"
            echo
            echo "Details:"
            echo "$details"
            echo
            echo "This is an automated message from the restore point system."
        } | sendmail -t
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            POINT_NAME="$2"
            shift 2
            ;;
        -d|--desc)
            DESCRIPTION="$2"
            shift 2
            ;;
        -i|--include)
            INCLUDE_DIRS+=("$2")
            shift 2
            ;;
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
            MAX_POINTS="$2"
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
            if [ -z "$ACTION" ]; then
                ACTION="$1"
            elif [ -z "$RESTORE_DIR" ]; then
                RESTORE_DIR="$1"
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
if [ -z "$ACTION" ] || [ -z "$RESTORE_DIR" ]; then
    echo "Error: Action and restore directory are required"
    print_usage
    exit 1
fi

# Validate action
case "$ACTION" in
    create|list|show|restore|delete|verify)
        ;;
    *)
        echo "Error: Invalid action: $ACTION"
        print_usage
        exit 1
        ;;
esac

# Create restore directory if it doesn't exist
mkdir -p "$RESTORE_DIR"

# Use default include directories if none specified
if [ ${#INCLUDE_DIRS[@]} -eq 0 ]; then
    INCLUDE_DIRS=("${DEFAULT_INCLUDE_DIRS[@]}")
fi

# Main execution
log_message "INFO" "Starting restore point action: $ACTION"

case "$ACTION" in
    create)
        if [ -z "$POINT_NAME" ]; then
            POINT_NAME="restore_$(date +%Y%m%d_%H%M%S)"
        fi
        backup_start=$(date +%s)
        backup_file=$(create_restore_point)
        backup_end=$(date +%s)
        backup_duration=$((backup_end - backup_start))
        
        if [ "$DRY_RUN" = false ]; then
            # Cleanup old points
            cleanup_old_points
            
            # Calculate backup size
            backup_size=$(get_dir_size "$backup_file")
            
            # Send notification
            details="Name: $POINT_NAME
Duration: $backup_duration seconds
Size: $(numfmt --to=iec-i --suffix=B $backup_size)
File: $backup_file
Included Directories:
$(printf '%s\n' "${INCLUDE_DIRS[@]}")"
            
            send_notification "Restore Point Created" "$details"
        fi
        ;;
    list)
        list_restore_points
        ;;
    show)
        if [ -z "$POINT_NAME" ]; then
            echo "Error: Restore point name is required for show action"
            exit 1
        fi
        show_restore_point
        ;;
    restore)
        if [ -z "$POINT_NAME" ]; then
            echo "Error: Restore point name is required for restore action"
            exit 1
        fi
        restore_from_point
        ;;
    delete)
        if [ -z "$POINT_NAME" ]; then
            echo "Error: Restore point name is required for delete action"
            exit 1
        fi
        delete_restore_point
        ;;
    verify)
        if [ -z "$POINT_NAME" ]; then
            echo "Error: Restore point name is required for verify action"
            exit 1
        fi
        verify_restore_point "$RESTORE_DIR/${POINT_NAME}.tar.*"
        ;;
esac

log_message "INFO" "Restore point action completed: $ACTION"
echo -e "\n${GREEN}Action complete. See $LOG_FILE for detailed log.${NC}"
