#!/bin/bash

# deploy.sh
# Advanced build and deployment automation
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

# Default values
PROJECT_DIR=""
ENVIRONMENT="dev"  # dev, staging, prod
BUILD_TYPE=""      # docker, binary, package
TARGET_HOST=""
TARGET_PATH=""
CONFIG_FILE=""
BACKUP=true
ROLLBACK=true
HEALTH_CHECK=true
NOTIFY=true
DRY_RUN=false
LOG_FILE=""
VERBOSE=false
TIMEOUT=300
RETRY_COUNT=3
DEPLOY_USER=""
SSH_KEY=""
DOCKER_REGISTRY=""
VERSION=""
ARTIFACTS_DIR="./artifacts"
SECRETS_FILE=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] PROJECT_DIR"
    echo
    echo "Options:"
    echo "  -e, --env ENV        Target environment (dev|staging|prod)"
    echo "  -t, --type TYPE      Build type (docker|binary|package)"
    echo "  -h, --host HOST      Target host"
    echo "  -p, --path PATH      Target path"
    echo "  -c, --config FILE    Configuration file"
    echo "  --no-backup         Don't create backup"
    echo "  --no-rollback       Disable rollback"
    echo "  --no-health         Skip health check"
    echo "  --no-notify         Disable notifications"
    echo "  --dry-run           Simulation mode"
    echo "  --log FILE          Log file path"
    echo "  -v, --verbose       Verbose output"
    echo "  --timeout SEC       Operation timeout"
    echo "  --retries NUM       Number of retries"
    echo "  -u, --user USER     Deploy user"
    echo "  -k, --key FILE      SSH key file"
    echo "  -r, --registry URL  Docker registry URL"
    echo "  --version VER       Version to deploy"
    echo "  --artifacts DIR     Artifacts directory"
    echo "  -s, --secrets FILE  Secrets file"
    echo "  --help              Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ -n "$LOG_FILE" ]; then
        echo -e "${timestamp} [$level] - ${message}" >> "$LOG_FILE"
    fi
    [ "$VERBOSE" = true ] && echo -e "[$level] ${message}"
}

# Function to validate environment
validate_environment() {
    local env="$1"
    case "$env" in
        dev|staging|prod) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to validate build type
validate_build_type() {
    local type="$1"
    case "$type" in
        docker|binary|package) return 0 ;;
        *) return 1 ;;
    esac
}

# Function to load configuration
load_config() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_message "ERROR" "Configuration file not found: $file"
        exit 1
    fi
    source "$file"
}

# Function to load secrets
load_secrets() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_message "ERROR" "Secrets file not found: $file"
        exit 1
    fi
    source "$file"
}

# Function to create backup
create_backup() {
    local host="$1"
    local path="$2"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="$ARTIFACTS_DIR/backups/$timestamp"
    
    log_message "INFO" "Creating backup..."
    
    mkdir -p "$backup_dir"
    
    if [ -n "$host" ]; then
        rsync -az -e "ssh -i $SSH_KEY" "$DEPLOY_USER@$host:$path/" "$backup_dir/"
    else
        rsync -az "$path/" "$backup_dir/"
    fi
    
    echo "$backup_dir"
}

# Function to perform rollback
do_rollback() {
    local host="$1"
    local path="$2"
    local backup_dir="$3"
    
    log_message "INFO" "Performing rollback..."
    
    if [ -n "$host" ]; then
        rsync -az --delete -e "ssh -i $SSH_KEY" "$backup_dir/" "$DEPLOY_USER@$host:$path/"
    else
        rsync -az --delete "$backup_dir/" "$path/"
    fi
}

# Function to check health
check_health() {
    local host="$1"
    local path="$2"
    local attempts=0
    
    log_message "INFO" "Checking health..."
    
    while [ $attempts -lt $RETRY_COUNT ]; do
        if curl -sf "http://$host/health" > /dev/null; then
            return 0
        fi
        ((attempts++))
        sleep 5
    done
    
    return 1
}

# Function to send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    log_message "INFO" "Sending notification: $status - $message"
    
    # Implement notification logic (email, Slack, etc.)
    # Example: curl -X POST -H "Content-Type: application/json" \
    #          -d "{\"text\":\"$message\"}" \
    #          "$SLACK_WEBHOOK_URL"
}

# Function to build Docker image
build_docker() {
    local dir="$1"
    local version="$2"
    
    log_message "INFO" "Building Docker image..."
    
    docker build -t "$DOCKER_REGISTRY/$PROJECT_NAME:$version" "$dir"
    
    if [ "$DRY_RUN" = false ]; then
        docker push "$DOCKER_REGISTRY/$PROJECT_NAME:$version"
    fi
}

# Function to build binary
build_binary() {
    local dir="$1"
    local version="$2"
    
    log_message "INFO" "Building binary..."
    
    # Implement binary build logic based on project type
    # Example: go build -o "$ARTIFACTS_DIR/bin/$PROJECT_NAME"
}

# Function to build package
build_package() {
    local dir="$1"
    local version="$2"
    
    log_message "INFO" "Building package..."
    
    # Implement package build logic based on project type
    # Example: python setup.py sdist bdist_wheel
}

# Function to deploy Docker container
deploy_docker() {
    local host="$1"
    local version="$2"
    
    log_message "INFO" "Deploying Docker container..."
    
    ssh -i "$SSH_KEY" "$DEPLOY_USER@$host" << EOF
        docker pull "$DOCKER_REGISTRY/$PROJECT_NAME:$version"
        docker stop "$PROJECT_NAME" || true
        docker rm "$PROJECT_NAME" || true
        docker run -d --name "$PROJECT_NAME" "$DOCKER_REGISTRY/$PROJECT_NAME:$version"
EOF
}

# Function to deploy binary
deploy_binary() {
    local host="$1"
    local path="$2"
    local version="$3"
    
    log_message "INFO" "Deploying binary..."
    
    rsync -az -e "ssh -i $SSH_KEY" \
        "$ARTIFACTS_DIR/bin/" \
        "$DEPLOY_USER@$host:$path/"
}

# Function to deploy package
deploy_package() {
    local host="$1"
    local path="$2"
    local version="$3"
    
    log_message "INFO" "Deploying package..."
    
    rsync -az -e "ssh -i $SSH_KEY" \
        "$ARTIFACTS_DIR/dist/" \
        "$DEPLOY_USER@$host:$path/"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -h|--host)
            TARGET_HOST="$2"
            shift 2
            ;;
        -p|--path)
            TARGET_PATH="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --no-backup)
            BACKUP=false
            shift
            ;;
        --no-rollback)
            ROLLBACK=false
            shift
            ;;
        --no-health)
            HEALTH_CHECK=false
            shift
            ;;
        --no-notify)
            NOTIFY=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --retries)
            RETRY_COUNT="$2"
            shift 2
            ;;
        -u|--user)
            DEPLOY_USER="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -r|--registry)
            DOCKER_REGISTRY="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --artifacts)
            ARTIFACTS_DIR="$2"
            shift 2
            ;;
        -s|--secrets)
            SECRETS_FILE="$2"
            shift 2
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$PROJECT_DIR" ]; then
                PROJECT_DIR="$1"
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
if [ -z "$PROJECT_DIR" ]; then
    echo "Error: Project directory is required"
    print_usage
    exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory does not exist: $PROJECT_DIR"
    exit 1
fi

if ! validate_environment "$ENVIRONMENT"; then
    echo "Error: Invalid environment: $ENVIRONMENT"
    exit 1
fi

if [ -z "$BUILD_TYPE" ]; then
    echo "Error: Build type is required"
    exit 1
fi

if ! validate_build_type "$BUILD_TYPE"; then
    echo "Error: Invalid build type: $BUILD_TYPE"
    exit 1
fi

if [ -z "$VERSION" ]; then
    VERSION=$(git -C "$PROJECT_DIR" describe --tags --always)
fi

# Initialize log file
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Create artifacts directory
mkdir -p "$ARTIFACTS_DIR"

# Load configuration and secrets
if [ -n "$CONFIG_FILE" ]; then
    load_config "$CONFIG_FILE"
fi

if [ -n "$SECRETS_FILE" ]; then
    load_secrets "$SECRETS_FILE"
fi

# Start deployment
log_message "INFO" "Starting deployment"
log_message "INFO" "Environment: $ENVIRONMENT"
log_message "INFO" "Build type: $BUILD_TYPE"
log_message "INFO" "Version: $VERSION"

# Create backup if enabled
BACKUP_DIR=""
if [ "$BACKUP" = true ] && [ -n "$TARGET_HOST" ] && [ -n "$TARGET_PATH" ]; then
    BACKUP_DIR=$(create_backup "$TARGET_HOST" "$TARGET_PATH")
fi

# Build artifacts
case "$BUILD_TYPE" in
    docker)
        build_docker "$PROJECT_DIR" "$VERSION"
        ;;
    binary)
        build_binary "$PROJECT_DIR" "$VERSION"
        ;;
    package)
        build_package "$PROJECT_DIR" "$VERSION"
        ;;
esac

if [ "$DRY_RUN" = true ]; then
    log_message "INFO" "Dry run completed"
    exit 0
fi

# Deploy artifacts
SUCCESS=false
if [ -n "$TARGET_HOST" ]; then
    case "$BUILD_TYPE" in
        docker)
            deploy_docker "$TARGET_HOST" "$VERSION"
            ;;
        binary)
            deploy_binary "$TARGET_HOST" "$TARGET_PATH" "$VERSION"
            ;;
        package)
            deploy_package "$TARGET_HOST" "$TARGET_PATH" "$VERSION"
            ;;
    esac
    
    # Health check
    if [ "$HEALTH_CHECK" = true ]; then
        if check_health "$TARGET_HOST" "$TARGET_PATH"; then
            SUCCESS=true
        elif [ "$ROLLBACK" = true ] && [ -n "$BACKUP_DIR" ]; then
            log_message "ERROR" "Health check failed, performing rollback"
            do_rollback "$TARGET_HOST" "$TARGET_PATH" "$BACKUP_DIR"
        fi
    else
        SUCCESS=true
    fi
else
    SUCCESS=true
fi

# Send notification
if [ "$NOTIFY" = true ]; then
    if [ "$SUCCESS" = true ]; then
        send_notification "SUCCESS" "Deployment completed successfully"
    else
        send_notification "FAILURE" "Deployment failed"
    fi
fi

# Cleanup
if [ -n "$BACKUP_DIR" ] && [ "$SUCCESS" = true ]; then
    rm -rf "$BACKUP_DIR"
fi

if [ "$SUCCESS" = true ]; then
    log_message "INFO" "Deployment completed successfully"
    exit 0
else
    log_message "ERROR" "Deployment failed"
    exit 1
fi
