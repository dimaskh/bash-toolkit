#!/bin/bash

# docker-cleanup.sh
# Advanced Docker resource cleanup and management script
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
LOG_FILE="/var/log/docker-cleanup-$(date +%Y%m%d).log"

# Default values
DRY_RUN=false
FORCE=false
ALL=false
PRUNE_VOLUMES=false
DAYS_OLD=7
SIZE_THRESHOLD="10GB"
EXCLUDE_PATTERNS=()
INCLUDE_PATTERNS=()

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -a, --all               Remove all unused resources"
    echo "  -c, --containers        Remove stopped containers"
    echo "  -i, --images           Remove dangling images"
    echo "  -v, --volumes          Remove unused volumes"
    echo "  -n, --networks         Remove unused networks"
    echo "  -o, --older DAYS       Remove items older than DAYS (default: 7)"
    echo "  -s, --size SIZE        Remove images larger than SIZE (default: 10GB)"
    echo "  -e, --exclude PATTERN  Exclude items matching pattern"
    echo "  -p, --pattern PATTERN  Include only items matching pattern"
    echo "  -f, --force            Don't ask for confirmation"
    echo "  -d, --dry-run          Show what would be removed"
    echo "  -h, --help             Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" | sudo tee -a "$LOG_FILE"
    echo -e "[$level] ${message}"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_message "ERROR" "Docker is not running or you don't have sufficient permissions"
        exit 1
    fi
}

# Function to format size string to bytes
size_to_bytes() {
    local size="$1"
    local unit="${size: -2}"
    local number="${size%??}"
    
    case "$unit" in
        KB) echo "$((number * 1024))" ;;
        MB) echo "$((number * 1024 * 1024))" ;;
        GB) echo "$((number * 1024 * 1024 * 1024))" ;;
        TB) echo "$((number * 1024 * 1024 * 1024 * 1024))" ;;
        *) echo "$number" ;;
    esac
}

# Function to check if item matches patterns
matches_pattern() {
    local item="$1"
    local matched=false
    
    # Check include patterns
    if [ ${#INCLUDE_PATTERNS[@]} -gt 0 ]; then
        for pattern in "${INCLUDE_PATTERNS[@]}"; do
            if [[ "$item" =~ $pattern ]]; then
                matched=true
                break
            fi
        done
        [ "$matched" = false ] && return 1
    fi
    
    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$item" =~ $pattern ]]; then
            return 1
        fi
    done
    
    return 0
}

# Function to cleanup containers
cleanup_containers() {
    log_message "INFO" "Checking for containers to remove..."
    
    local containers=$(docker ps -a -q -f status=exited -f status=created)
    [ -z "$containers" ] && return 0
    
    local to_remove=()
    for container in $containers; do
        local name=$(docker inspect --format '{{.Name}}' "$container")
        local created=$(docker inspect --format '{{.Created}}' "$container")
        local age=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))
        
        if [ "$age" -gt "$DAYS_OLD" ] && matches_pattern "$name"; then
            to_remove+=("$container")
            if [ "$DRY_RUN" = true ]; then
                echo "Would remove container: $name (age: $age days)"
            fi
        fi
    done
    
    if [ ${#to_remove[@]} -gt 0 ] && [ "$DRY_RUN" = false ]; then
        if [ "$FORCE" = true ] || confirm "Remove ${#to_remove[@]} containers?"; then
            docker rm "${to_remove[@]}"
            log_message "INFO" "Removed ${#to_remove[@]} containers"
        fi
    fi
}

# Function to cleanup images
cleanup_images() {
    log_message "INFO" "Checking for images to remove..."
    
    local images=$(docker images -q)
    [ -z "$images" ] && return 0
    
    local to_remove=()
    for image in $images; do
        local tags=$(docker inspect --format '{{.RepoTags}}' "$image")
        local size=$(docker inspect --format '{{.Size}}' "$image")
        local created=$(docker inspect --format '{{.Created}}' "$image")
        local age=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))
        
        if [ "$size" -gt "$(size_to_bytes "$SIZE_THRESHOLD")" ] && \
           [ "$age" -gt "$DAYS_OLD" ] && \
           matches_pattern "$tags"; then
            to_remove+=("$image")
            if [ "$DRY_RUN" = true ]; then
                echo "Would remove image: $tags (size: $size bytes, age: $age days)"
            fi
        fi
    done
    
    if [ ${#to_remove[@]} -gt 0 ] && [ "$DRY_RUN" = false ]; then
        if [ "$FORCE" = true ] || confirm "Remove ${#to_remove[@]} images?"; then
            docker rmi "${to_remove[@]}"
            log_message "INFO" "Removed ${#to_remove[@]} images"
        fi
    fi
}

# Function to cleanup volumes
cleanup_volumes() {
    log_message "INFO" "Checking for volumes to remove..."
    
    if [ "$PRUNE_VOLUMES" = true ] || [ "$ALL" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            docker volume ls -qf dangling=true
        else
            if [ "$FORCE" = true ] || confirm "Remove all unused volumes?"; then
                docker volume prune -f
                log_message "INFO" "Removed unused volumes"
            fi
        fi
    fi
}

# Function to cleanup networks
cleanup_networks() {
    log_message "INFO" "Checking for networks to remove..."
    
    if [ "$ALL" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            docker network ls -qf dangling=true
        else
            if [ "$FORCE" = true ] || confirm "Remove all unused networks?"; then
                docker network prune -f
                log_message "INFO" "Removed unused networks"
            fi
        fi
    fi
}

# Function to ask for confirmation
confirm() {
    local message="$1"
    read -p "$message [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Parse command line arguments
CLEANUP_CONTAINERS=false
CLEANUP_IMAGES=false
CLEANUP_VOLUMES=false
CLEANUP_NETWORKS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            ALL=true
            shift
            ;;
        -c|--containers)
            CLEANUP_CONTAINERS=true
            shift
            ;;
        -i|--images)
            CLEANUP_IMAGES=true
            shift
            ;;
        -v|--volumes)
            CLEANUP_VOLUMES=true
            shift
            ;;
        -n|--networks)
            CLEANUP_NETWORKS=true
            shift
            ;;
        -o|--older)
            DAYS_OLD="$2"
            shift 2
            ;;
        -s|--size)
            SIZE_THRESHOLD="$2"
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -p|--pattern)
            INCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -d|--dry-run)
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
log_message "INFO" "Starting Docker cleanup"

# Check Docker availability
check_docker

# Set default cleanup if none specified
if [ "$ALL" = false ] && \
   [ "$CLEANUP_CONTAINERS" = false ] && \
   [ "$CLEANUP_IMAGES" = false ] && \
   [ "$CLEANUP_VOLUMES" = false ] && \
   [ "$CLEANUP_NETWORKS" = false ]; then
    CLEANUP_CONTAINERS=true
    CLEANUP_IMAGES=true
fi

# Perform cleanup
[ "$CLEANUP_CONTAINERS" = true ] || [ "$ALL" = true ] && cleanup_containers
[ "$CLEANUP_IMAGES" = true ] || [ "$ALL" = true ] && cleanup_images
[ "$CLEANUP_VOLUMES" = true ] || [ "$ALL" = true ] && cleanup_volumes
[ "$CLEANUP_NETWORKS" = true ] || [ "$ALL" = true ] && cleanup_networks

log_message "INFO" "Cleanup completed"
echo -e "\n${GREEN}Cleanup complete. Check $LOG_FILE for detailed log.${NC}"
