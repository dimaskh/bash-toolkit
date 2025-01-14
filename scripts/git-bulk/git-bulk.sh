#!/bin/bash

# git-bulk.sh
# Bulk operations for multiple Git repositories
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
LOG_FILE="$HOME/.git-bulk-$(date +%Y%m%d).log"

# Default values
SEARCH_DIR="."
RECURSIVE=false
MAX_DEPTH=3
PARALLEL=false
DRY_RUN=false
VERBOSE=false
BRANCH=""
REMOTE=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo
    echo "Commands:"
    echo "  status              Show status of all repositories"
    echo "  fetch [remote]      Fetch from remote"
    echo "  pull [remote]       Pull from remote"
    echo "  push [remote]       Push to remote"
    echo "  checkout <branch>   Checkout branch"
    echo "  clean              Remove untracked files"
    echo "  reset              Reset to HEAD"
    echo "  branch             Show current branch of all repositories"
    echo "  stash              Stash changes"
    echo "  unstash            Pop stashed changes"
    echo
    echo "Options:"
    echo "  -d, --directory DIR    Base directory (default: current)"
    echo "  -r, --recursive        Search recursively"
    echo "  -m, --max-depth N      Maximum recursion depth (default: 3)"
    echo "  -p, --parallel         Run operations in parallel"
    echo "  -n, --dry-run          Show what would be done"
    echo "  -v, --verbose          Verbose output"
    echo "  -h, --help             Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" >> "$LOG_FILE"
    [ "$VERBOSE" = true ] && echo -e "[$level] ${message}"
}

# Function to check if directory is a git repository
is_git_repo() {
    git -C "$1" rev-parse --git-dir >/dev/null 2>&1
}

# Function to find git repositories
find_git_repos() {
    local base_dir="$1"
    local depth_arg=""
    
    [ "$RECURSIVE" = true ] && depth_arg="-maxdepth $MAX_DEPTH"
    
    find "$base_dir" $depth_arg -type d -exec sh -c '
        for dir; do
            if [ -d "$dir/.git" ]; then
                echo "$dir"
            fi
        done
    ' sh {} +
}

# Function to execute git command
execute_git_command() {
    local repo="$1"
    shift
    local command=("$@")
    
    if [ "$DRY_RUN" = true ]; then
        echo "Would execute in $repo: git ${command[*]}"
        return 0
    fi
    
    echo -e "\n${BLUE}=== Repository: $repo ===${NC}"
    
    if ! cd "$repo"; then
        log_message "ERROR" "Failed to change to directory: $repo"
        return 1
    fi
    
    if git "${command[@]}" 2>&1; then
        log_message "INFO" "Successfully executed 'git ${command[*]}' in $repo"
        return 0
    else
        log_message "ERROR" "Failed to execute 'git ${command[*]}' in $repo"
        return 1
    fi
}

# Function to execute command in parallel
parallel_execute() {
    local repos=("$@")
    local pids=()
    
    for repo in "${repos[@]}"; do
        execute_git_command "$repo" "${GIT_COMMAND[@]}" &
        pids+=($!)
    done
    
    # Wait for all processes to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            SEARCH_DIR="$2"
            shift 2
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -m|--max-depth)
            MAX_DEPTH="$2"
            shift 2
            ;;
        -p|--parallel)
            PARALLEL=true
            shift
            ;;
        -n|--dry-run)
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
            break
            ;;
    esac
done

# Check for command
if [ $# -eq 0 ]; then
    echo "Error: No command specified"
    print_usage
    exit 1
fi

COMMAND="$1"
shift

# Prepare git command based on input
case "$COMMAND" in
    status)
        GIT_COMMAND=(status --short)
        ;;
    fetch)
        REMOTE="${1:-origin}"
        GIT_COMMAND=(fetch "$REMOTE")
        ;;
    pull)
        REMOTE="${1:-origin}"
        GIT_COMMAND=(pull "$REMOTE")
        ;;
    push)
        REMOTE="${1:-origin}"
        GIT_COMMAND=(push "$REMOTE")
        ;;
    checkout)
        if [ $# -eq 0 ]; then
            echo "Error: Branch name required for checkout"
            exit 1
        fi
        BRANCH="$1"
        GIT_COMMAND=(checkout "$BRANCH")
        ;;
    clean)
        GIT_COMMAND=(clean -fd)
        ;;
    reset)
        GIT_COMMAND=(reset --hard HEAD)
        ;;
    branch)
        GIT_COMMAND=(branch --show-current)
        ;;
    stash)
        GIT_COMMAND=(stash)
        ;;
    unstash)
        GIT_COMMAND=(stash pop)
        ;;
    *)
        echo "Error: Unknown command: $COMMAND"
        print_usage
        exit 1
        ;;
esac

# Find repositories
log_message "INFO" "Searching for Git repositories in $SEARCH_DIR"
REPOS=($(find_git_repos "$SEARCH_DIR"))

if [ ${#REPOS[@]} -eq 0 ]; then
    log_message "ERROR" "No Git repositories found in $SEARCH_DIR"
    exit 1
fi

log_message "INFO" "Found ${#REPOS[@]} repositories"

# Execute commands
if [ "$PARALLEL" = true ]; then
    parallel_execute "${REPOS[@]}"
else
    for repo in "${REPOS[@]}"; do
        execute_git_command "$repo" "${GIT_COMMAND[@]}"
    done
fi

log_message "INFO" "Bulk operation completed"
echo -e "\n${GREEN}Operation complete. Check $LOG_FILE for detailed log.${NC}"
