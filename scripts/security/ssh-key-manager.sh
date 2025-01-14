#!/bin/bash

# ssh-key-manager.sh
# SSH key management and monitoring tool
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
LOG_FILE="$HOME/.ssh-key-manager-$(date +%Y%m%d).log"

# Default values
ACTION=""
KEY_TYPE="ed25519"
KEY_NAME=""
KEY_COMMENT=""
KEY_SIZE="4096"
BACKUP_DIR="$HOME/.ssh/backups"
OUTPUT_FORMAT="text"
VERBOSE=false
FORCE=false
CHECK_EXPIRY=false
EXPIRY_WARNING=30
SCAN_AUTHORIZED=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] ACTION"
    echo
    echo "Actions:"
    echo "  generate    Generate new SSH key pair"
    echo "  list        List existing SSH keys"
    echo "  backup      Backup SSH keys"
    echo "  restore     Restore SSH keys from backup"
    echo "  check       Check SSH key security"
    echo "  revoke      Revoke SSH key"
    echo "  rotate      Rotate SSH keys"
    echo "  scan        Scan authorized_keys"
    echo
    echo "Options:"
    echo "  -t, --type TYPE      Key type (rsa|ed25519|ecdsa)"
    echo "  -b, --bits BITS      Key size (for RSA)"
    echo "  -n, --name NAME      Key name"
    echo "  -c, --comment TEXT   Key comment"
    echo "  -f, --format FORMAT  Output format (text|json|csv)"
    echo "  -e, --expiry DAYS    Check key expiry"
    echo "  --force             Force operations"
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

# Function to format output
format_output() {
    local key_file="$1"
    local type="$2"
    local fingerprint="$3"
    local comment="$4"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"key":"%s","type":"%s","fingerprint":"%s","comment":"%s"}\n' \
                "$key_file" "$type" "$fingerprint" "$comment"
            ;;
        "csv")
            printf '%s,%s,%s,%s\n' "$key_file" "$type" "$fingerprint" "$comment"
            ;;
        *)
            printf "%-30s %-8s %-45s %s\n" "$key_file" "$type" "$fingerprint" "$comment"
            ;;
    esac
}

# Function to generate SSH key
generate_key() {
    local key_path="$HOME/.ssh/$KEY_NAME"
    
    if [ -f "$key_path" ] && [ "$FORCE" != true ]; then
        echo "Error: Key already exists. Use --force to overwrite."
        exit 1
    fi
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    # Generate key
    if [ "$KEY_TYPE" = "rsa" ]; then
        ssh-keygen -t rsa -b "$KEY_SIZE" -f "$key_path" -N "" -C "$KEY_COMMENT"
    else
        ssh-keygen -t "$KEY_TYPE" -f "$key_path" -N "" -C "$KEY_COMMENT"
    fi
    
    chmod 600 "$key_path"
    chmod 644 "$key_path.pub"
    
    echo -e "${GREEN}Generated new $KEY_TYPE key pair: $key_path${NC}"
}

# Function to list SSH keys
list_keys() {
    local ssh_dir="$HOME/.ssh"
    
    # Header for text output
    if [ "$OUTPUT_FORMAT" = "text" ]; then
        printf "%-30s %-8s %-45s %s\n" "Key" "Type" "Fingerprint" "Comment"
        printf "%s\n" "--------------------------------------------------------------------------------"
    fi
    
    # Find all private keys
    find "$ssh_dir" -type f -name 'id_*' ! -name '*.pub' | while read -r key_file; do
        [ -f "$key_file.pub" ] || continue
        
        local type
        local fingerprint
        local comment
        
        type=$(ssh-keygen -l -f "$key_file" | awk '{print $4}')
        fingerprint=$(ssh-keygen -l -f "$key_file" | awk '{print $2}')
        comment=$(ssh-keygen -l -f "$key_file" | cut -d' ' -f4-)
        
        format_output "$(basename "$key_file")" "$type" "$fingerprint" "$comment"
    done
}

# Function to backup SSH keys
backup_keys() {
    local backup_date
    backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/ssh_backup_$backup_date"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    
    # Create tar archive
    tar -czf "$backup_path.tar.gz" -C "$HOME/.ssh" .
    chmod 600 "$backup_path.tar.gz"
    
    echo -e "${GREEN}Backup created: $backup_path.tar.gz${NC}"
}

# Function to restore SSH keys
restore_keys() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        echo "Error: Backup file not found"
        exit 1
    fi
    
    if [ "$FORCE" != true ]; then
        echo "Warning: This will overwrite existing keys"
        read -rp "Continue? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
    fi
    
    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Extract backup
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Restore keys
    rsync -av --chmod=D700,F600 "$temp_dir/" "$HOME/.ssh/"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Keys restored from: $backup_file${NC}"
}

# Function to check key security
check_key() {
    local key_file="$1"
    local issues=()
    
    # Check permissions
    local perms
    perms=$(stat -c "%a" "$key_file")
    if [ "$perms" != "600" ]; then
        issues+=("Incorrect permissions: $perms (should be 600)")
    fi
    
    # Check key type and size
    local key_info
    key_info=$(ssh-keygen -l -f "$key_file")
    local key_bits
    key_bits=$(echo "$key_info" | awk '{print $1}')
    local key_type
    key_type=$(echo "$key_info" | awk '{print $4}')
    
    case "$key_type" in
        "RSA")
            [ "$key_bits" -lt 3072 ] && issues+=("RSA key size < 3072 bits")
            ;;
        "DSA")
            issues+=("DSA keys are deprecated")
            ;;
    esac
    
    # Check key age if enabled
    if [ "$CHECK_EXPIRY" = true ]; then
        local key_age
        key_age=$(($(date +%s) - $(stat -c %Y "$key_file")))
        key_age=$((key_age / 86400))  # Convert to days
        
        if [ "$key_age" -gt "$EXPIRY_WARNING" ]; then
            issues+=("Key age: $key_age days (warning: > $EXPIRY_WARNING days)")
        fi
    fi
    
    # Output issues
    if [ ${#issues[@]} -gt 0 ]; then
        echo -e "${YELLOW}Issues for $key_file:${NC}"
        printf '%s\n' "${issues[@]}"
    fi
}

# Function to revoke key
revoke_key() {
    local key_file="$1"
    
    if [ ! -f "$key_file" ]; then
        echo "Error: Key file not found"
        exit 1
    fi
    
    if [ "$FORCE" != true ]; then
        echo "Warning: This will permanently delete the key"
        read -rp "Continue? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
    fi
    
    # Remove private and public key
    rm -f "$key_file" "$key_file.pub"
    
    echo -e "${GREEN}Revoked key: $key_file${NC}"
}

# Function to rotate keys
rotate_keys() {
    local old_key="$1"
    local new_name="${old_key%.*}_new"
    
    # Generate new key
    KEY_NAME="$new_name"
    generate_key
    
    # Backup old key
    mv "$old_key" "$old_key.old"
    mv "$old_key.pub" "$old_key.pub.old"
    
    # Move new key to replace old key
    mv "$HOME/.ssh/$new_name" "$old_key"
    mv "$HOME/.ssh/$new_name.pub" "$old_key.pub"
    
    echo -e "${GREEN}Rotated key: $old_key${NC}"
}

# Function to scan authorized_keys
scan_authorized_keys() {
    local auth_keys="$HOME/.ssh/authorized_keys"
    
    if [ ! -f "$auth_keys" ]; then
        echo "No authorized_keys file found"
        return
    fi
    
    echo "Scanning authorized_keys:"
    echo
    
    while read -r line; do
        [ -z "$line" ] && continue
        [ "${line:0:1}" = "#" ] && continue
        
        local key_type
        local key_data
        local key_comment
        
        key_type=$(echo "$line" | awk '{print $1}')
        key_data=$(echo "$line" | awk '{print $2}')
        key_comment=$(echo "$line" | cut -d' ' -f3-)
        
        local fingerprint
        fingerprint=$(echo "$key_data" | base64 -d 2>/dev/null | ssh-keygen -l -f - 2>/dev/null | awk '{print $2}')
        
        format_output "authorized_keys" "$key_type" "$fingerprint" "$key_comment"
    done < "$auth_keys"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            KEY_TYPE="$2"
            shift 2
            ;;
        -b|--bits)
            KEY_SIZE="$2"
            shift 2
            ;;
        -n|--name)
            KEY_NAME="$2"
            shift 2
            ;;
        -c|--comment)
            KEY_COMMENT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -e|--expiry)
            CHECK_EXPIRY=true
            EXPIRY_WARNING="$2"
            shift 2
            ;;
        --force)
            FORCE=true
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
if [ -z "$ACTION" ]; then
    echo "Error: No action specified"
    print_usage
    exit 1
fi

# Set default key name if not specified
if [ -z "$KEY_NAME" ]; then
    KEY_NAME="id_${KEY_TYPE}"
fi

# Main execution
log_message "INFO" "Starting SSH key management: $ACTION"

case "$ACTION" in
    "generate")
        generate_key
        ;;
    "list")
        list_keys
        ;;
    "backup")
        backup_keys
        ;;
    "restore")
        if [ -z "$2" ]; then
            echo "Error: No backup file specified"
            exit 1
        fi
        restore_keys "$2"
        ;;
    "check")
        find "$HOME/.ssh" -type f -name 'id_*' ! -name '*.pub' -exec bash -c 'check_key "$0"' {} \;
        ;;
    "revoke")
        if [ -z "$2" ]; then
            echo "Error: No key specified"
            exit 1
        fi
        revoke_key "$2"
        ;;
    "rotate")
        if [ -z "$2" ]; then
            echo "Error: No key specified"
            exit 1
        fi
        rotate_keys "$2"
        ;;
    "scan")
        scan_authorized_keys
        ;;
    *)
        echo "Error: Invalid action"
        print_usage
        exit 1
        ;;
esac

log_message "INFO" "SSH key management completed"
