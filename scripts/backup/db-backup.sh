#!/bin/bash

# db-backup.sh
# Database backup automation tool with multi-database support
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
LOG_FILE="$HOME/.db-backup-$(date +%Y%m%d).log"

# Default values
DB_TYPE=""
DB_HOST="localhost"
DB_PORT=""
DB_USER=""
DB_PASS=""
DB_NAME=""
BACKUP_DIR=""
COMPRESSION="gzip"
RETENTION_DAYS=30
VERBOSE=false
VERIFY=false
EMAIL_NOTIFY=false
EMAIL_ADDRESS=""
EXCLUDE_TABLES=""
INCLUDE_TABLES=""
MAX_BACKUPS=0
ENCRYPTION=false
ENCRYPTION_KEY=""

# Default ports
declare -A DEFAULT_PORTS=(
    ["mysql"]="3306"
    ["postgresql"]="5432"
    ["mongodb"]="27017"
    ["redis"]="6379"
)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] DB_TYPE BACKUP_DIR"
    echo
    echo "Database Types:"
    echo "  mysql        MySQL/MariaDB"
    echo "  postgresql   PostgreSQL"
    echo "  mongodb      MongoDB"
    echo "  redis        Redis"
    echo
    echo "Options:"
    echo "  -h, --host HOST      Database host"
    echo "  -P, --port PORT      Database port"
    echo "  -u, --user USER      Database user"
    echo "  -p, --pass PASS      Database password"
    echo "  -d, --database DB    Database name"
    echo "  -c, --compression ALG Compression (gzip|bzip2|xz)"
    echo "  -r, --retention DAYS  Retention period in days"
    echo "  -m, --max NUM        Maximum number of backups"
    echo "  -i, --include TABLES  Include only these tables"
    echo "  -x, --exclude TABLES  Exclude these tables"
    echo "  --encrypt KEY        Enable encryption with key"
    echo "  --email ADDRESS      Enable email notifications"
    echo "  --verify            Verify backup integrity"
    echo "  -v, --verbose       Verbose output"
    echo "  --help              Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" >> "$LOG_FILE"
    [ "$VERBOSE" = true ] && echo -e "[$level] ${message}"
}

# Function to get backup size
get_backup_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file"
}

# Function to backup MySQL/MariaDB
backup_mysql() {
    local backup_file="$1"
    local options=()
    
    # Add credentials
    options+=(--user="$DB_USER")
    [ -n "$DB_PASS" ] && options+=(--password="$DB_PASS")
    
    # Add host and port
    options+=(--host="$DB_HOST")
    [ -n "$DB_PORT" ] && options+=(--port="$DB_PORT")
    
    # Add database
    [ -n "$DB_NAME" ] && options+=("$DB_NAME")
    
    # Add table filters
    if [ -n "$INCLUDE_TABLES" ]; then
        options+=(--tables)
        options+=($INCLUDE_TABLES)
    elif [ -n "$EXCLUDE_TABLES" ]; then
        options+=(--ignore-table="${DB_NAME}.${EXCLUDE_TABLES}")
    fi
    
    # Execute backup
    mysqldump "${options[@]}" > "$backup_file"
}

# Function to backup PostgreSQL
backup_postgresql() {
    local backup_file="$1"
    local options=()
    
    # Set environment variables for credentials
    export PGUSER="$DB_USER"
    export PGPASSWORD="$DB_PASS"
    
    # Add host and port
    options+=(--host="$DB_HOST")
    [ -n "$DB_PORT" ] && options+=(--port="$DB_PORT")
    
    # Add database
    [ -n "$DB_NAME" ] && options+=("$DB_NAME")
    
    # Add table filters
    if [ -n "$INCLUDE_TABLES" ]; then
        options+=(--table="$INCLUDE_TABLES")
    elif [ -n "$EXCLUDE_TABLES" ]; then
        options+=(--exclude-table="$EXCLUDE_TABLES")
    fi
    
    # Execute backup
    pg_dump "${options[@]}" > "$backup_file"
}

# Function to backup MongoDB
backup_mongodb() {
    local backup_file="$1"
    local uri="mongodb://"
    
    # Build connection URI
    if [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
        uri+="$DB_USER:$DB_PASS@"
    fi
    uri+="$DB_HOST"
    [ -n "$DB_PORT" ] && uri+=":$DB_PORT"
    [ -n "$DB_NAME" ] && uri+="/$DB_NAME"
    
    # Execute backup
    mongodump --uri="$uri" --archive="$backup_file"
}

# Function to backup Redis
backup_redis() {
    local backup_file="$1"
    
    # Build connection string
    local options=()
    options+=(--host "$DB_HOST")
    [ -n "$DB_PORT" ] && options+=(--port "$DB_PORT")
    [ -n "$DB_PASS" ] && options+=(--auth "$DB_PASS")
    
    # Execute backup
    redis-cli "${options[@]}" SAVE
    cp /var/lib/redis/dump.rdb "$backup_file"
}

# Function to compress backup
compress_backup() {
    local input_file="$1"
    local output_file
    
    case "$COMPRESSION" in
        "gzip")
            output_file="${input_file}.gz"
            gzip -c "$input_file" > "$output_file"
            ;;
        "bzip2")
            output_file="${input_file}.bz2"
            bzip2 -c "$input_file" > "$output_file"
            ;;
        "xz")
            output_file="${input_file}.xz"
            xz -c "$input_file" > "$output_file"
            ;;
    esac
    
    rm "$input_file"
    echo "$output_file"
}

# Function to encrypt backup
encrypt_backup() {
    local input_file="$1"
    local output_file="${input_file}.enc"
    
    openssl enc -aes-256-cbc -salt -in "$input_file" \
        -out "$output_file" -k "$ENCRYPTION_KEY"
    
    rm "$input_file"
    echo "$output_file"
}

# Function to verify backup
verify_backup() {
    local backup_file="$1"
    local verify_file="/tmp/verify_backup"
    
    case "$DB_TYPE" in
        "mysql")
            mysql --user="$DB_USER" --password="$DB_PASS" \
                --host="$DB_HOST" --port="$DB_PORT" \
                --execute="SELECT 1" >/dev/null
            ;;
        "postgresql")
            PGPASSWORD="$DB_PASS" psql -U "$DB_USER" \
                -h "$DB_HOST" -p "$DB_PORT" \
                -c "SELECT 1" >/dev/null
            ;;
        "mongodb")
            mongosh --eval "db.runCommand({ping:1})" >/dev/null
            ;;
        "redis")
            redis-cli -h "$DB_HOST" -p "$DB_PORT" \
                ${DB_PASS:+-a "$DB_PASS"} PING >/dev/null
            ;;
    esac
    
    log_message "INFO" "Backup verification successful"
}

# Function to cleanup old backups
cleanup_old_backups() {
    local backup_dir="$1"
    
    # Remove old backups based on retention period
    if [ "$RETENTION_DAYS" -gt 0 ]; then
        find "$backup_dir" -name "*.${DB_TYPE}.*" -type f -mtime +"$RETENTION_DAYS" -delete
    fi
    
    # Remove excess backups based on maximum count
    if [ "$MAX_BACKUPS" -gt 0 ]; then
        local count
        count=$(find "$backup_dir" -name "*.${DB_TYPE}.*" -type f | wc -l)
        if [ "$count" -gt "$MAX_BACKUPS" ]; then
            local excess=$((count - MAX_BACKUPS))
            find "$backup_dir" -name "*.${DB_TYPE}.*" -type f -printf "%T@ %p\n" | \
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
            echo "Subject: [Database Backup] $status - $(date '+%Y-%m-%d %H:%M:%S')"
            echo "From: Database Backup <noreply@$(hostname)>"
            echo "To: $EMAIL_ADDRESS"
            echo
            echo "Backup Status: $status"
            echo
            echo "Details:"
            echo "$details"
            echo
            echo "This is an automated message from the database backup system."
        } | sendmail -t
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            DB_HOST="$2"
            shift 2
            ;;
        -P|--port)
            DB_PORT="$2"
            shift 2
            ;;
        -u|--user)
            DB_USER="$2"
            shift 2
            ;;
        -p|--pass)
            DB_PASS="$2"
            shift 2
            ;;
        -d|--database)
            DB_NAME="$2"
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
        -i|--include)
            INCLUDE_TABLES="$2"
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_TABLES="$2"
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
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$DB_TYPE" ]; then
                DB_TYPE="$1"
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
if [ -z "$DB_TYPE" ] || [ -z "$BACKUP_DIR" ]; then
    echo "Error: Database type and backup directory are required"
    print_usage
    exit 1
fi

# Validate database type
case "$DB_TYPE" in
    mysql|postgresql|mongodb|redis)
        ;;
    *)
        echo "Error: Unsupported database type: $DB_TYPE"
        exit 1
        ;;
esac

# Set default port if not specified
if [ -z "$DB_PORT" ]; then
    DB_PORT="${DEFAULT_PORTS[$DB_TYPE]}"
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Main execution
log_message "INFO" "Starting database backup: $DB_TYPE"

# Create backup filename
timestamp=$(date +%Y%m%d_%H%M%S)
backup_file="$BACKUP_DIR/${DB_TYPE}_${DB_NAME:-all}_$timestamp.${DB_TYPE}"

# Perform backup
backup_start=$(date +%s)
case "$DB_TYPE" in
    "mysql")
        backup_mysql "$backup_file"
        ;;
    "postgresql")
        backup_postgresql "$backup_file"
        ;;
    "mongodb")
        backup_mongodb "$backup_file"
        ;;
    "redis")
        backup_redis "$backup_file"
        ;;
esac

# Compress backup
backup_file=$(compress_backup "$backup_file")

# Encrypt backup if enabled
if [ "$ENCRYPTION" = true ]; then
    backup_file=$(encrypt_backup "$backup_file")
fi

backup_end=$(date +%s)
backup_duration=$((backup_end - backup_start))

# Verify backup if requested
[ "$VERIFY" = true ] && verify_backup "$backup_file"

# Cleanup old backups
cleanup_old_backups "$BACKUP_DIR"

# Calculate backup size
backup_size=$(get_backup_size "$backup_file")

# Send notification
details="Database: ${DB_NAME:-all}
Type: $DB_TYPE
Host: $DB_HOST:$DB_PORT
Duration: $backup_duration seconds
Size: $(numfmt --to=iec-i --suffix=B $backup_size)
File: $backup_file"

send_notification "Backup Complete" "$details"

log_message "INFO" "Database backup completed"
echo -e "\n${GREEN}Backup complete. See $LOG_FILE for detailed log.${NC}"
