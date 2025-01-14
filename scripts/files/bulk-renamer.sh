#!/bin/bash

# bulk-renamer.sh
# Advanced bulk file renaming tool with multiple renaming strategies
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
TARGET_DIR=""
PATTERN=""
REPLACEMENT=""
RENAME_MODE="pattern"  # pattern, sequence, date, case, clean
DRY_RUN=false
RECURSIVE=false
EXCLUDE_PATTERNS=()
INCLUDE_HIDDEN=false
FOLLOW_LINKS=false
PRESERVE_EXT=true
START_NUMBER=1
NUMBER_PADDING=3
DATE_FORMAT="%Y%m%d"
CASE_MODE="lower"  # lower, upper, title
LOG_FILE=""
PREVIEW=false
UNDO_FILE=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] TARGET_DIR [PATTERN] [REPLACEMENT]"
    echo
    echo "Options:"
    echo "  -m, --mode MODE      Rename mode (pattern|sequence|date|case|clean)"
    echo "  -d, --dry-run       Show what would be done"
    echo "  -r, --recursive     Process directories recursively"
    echo "  -e, --exclude PAT   Exclude pattern (can be used multiple times)"
    echo "  -H, --hidden        Include hidden files"
    echo "  -L, --follow-links  Follow symbolic links"
    echo "  -E, --no-ext       Don't preserve file extensions"
    echo "  -n, --start NUM     Starting number for sequence mode"
    echo "  -p, --padding NUM   Number padding for sequence mode"
    echo "  -f, --date-format FMT Date format for date mode"
    echo "  -c, --case MODE     Case mode (lower|upper|title)"
    echo "  --log FILE         Log file path"
    echo "  --preview          Show preview of changes"
    echo "  --undo FILE        Save undo information to file"
    echo "  -h, --help          Show this help message"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ -n "$LOG_FILE" ]; then
        echo -e "${timestamp} [$level] - ${message}" >> "$LOG_FILE"
    fi
    echo -e "[$level] ${message}"
}

# Function to clean filename
clean_filename() {
    local filename="$1"
    # Remove invalid characters and replace spaces
    echo "$filename" | tr -cd '[:alnum:][:space:].-_' | tr '[:space:]' '_' | tr -s '_'
}

# Function to convert case
convert_case() {
    local filename="$1"
    case "$CASE_MODE" in
        lower)
            echo "$filename" | tr '[:upper:]' '[:lower:]'
            ;;
        upper)
            echo "$filename" | tr '[:lower:]' '[:upper:]'
            ;;
        title)
            echo "$filename" | sed 's/\b\(.\)/\u\1/g'
            ;;
    esac
}

# Function to generate new filename
generate_new_name() {
    local file="$1"
    local counter="$2"
    local base_name=$(basename "$file")
    local dir_name=$(dirname "$file")
    local extension=""
    local name="$base_name"
    
    if [ "$PRESERVE_EXT" = true ] && [[ "$base_name" =~ \. ]]; then
        extension=".${base_name##*.}"
        name="${base_name%.*}"
    fi
    
    local new_name=""
    case "$RENAME_MODE" in
        pattern)
            if [ -n "$PATTERN" ] && [ -n "$REPLACEMENT" ]; then
                new_name=$(echo "$name" | sed "s/$PATTERN/$REPLACEMENT/g")
            else
                new_name="$name"
            fi
            ;;
        sequence)
            local padded_num=$(printf "%0${NUMBER_PADDING}d" $((START_NUMBER + counter - 1)))
            new_name="file_${padded_num}"
            ;;
        date)
            local file_date=$(date -r "$file" +"$DATE_FORMAT")
            new_name="${file_date}_${name}"
            ;;
        case)
            new_name=$(convert_case "$name")
            ;;
        clean)
            new_name=$(clean_filename "$name")
            ;;
    esac
    
    echo "$dir_name/$new_name$extension"
}

# Function to check for naming conflicts
check_conflicts() {
    local files=("$@")
    local new_names=()
    local has_conflicts=false
    
    for file in "${files[@]}"; do
        local new_name=$(generate_new_name "$file" 1)
        if [[ " ${new_names[@]} " =~ " ${new_name} " ]]; then
            log_message "ERROR" "Conflict detected: Multiple files would be renamed to $(basename "$new_name")"
            has_conflicts=true
        fi
        new_names+=("$new_name")
    done
    
    return $([ "$has_conflicts" = true ])
}

# Function to preview changes
preview_changes() {
    local files=("$@")
    local counter=1
    
    echo "Preview of changes:"
    echo "-----------------"
    printf "%-50s %s\n" "Original Name" "New Name"
    echo "------------------------------------------------"
    
    for file in "${files[@]}"; do
        local new_name=$(generate_new_name "$file" "$counter")
        printf "%-50s %s\n" "$(basename "$file")" "$(basename "$new_name")"
        ((counter++))
    done
}

# Function to save undo information
save_undo_info() {
    local old_name="$1"
    local new_name="$2"
    
    if [ -n "$UNDO_FILE" ]; then
        echo "$new_name:$old_name" >> "$UNDO_FILE"
    fi
}

# Function to rename files
rename_files() {
    local counter=1
    local renamed=0
    local skipped=0
    local errors=0
    declare -a files
    
    # Collect all files first
    while IFS= read -r file; do
        # Skip if file doesn't match criteria
        [[ "$file" =~ /\. ]] && [ "$INCLUDE_HIDDEN" = false ] && continue
        [[ -L "$file" ]] && [ "$FOLLOW_LINKS" = false ] && continue
        
        local excluded=false
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            if [[ "$file" =~ $pattern ]]; then
                excluded=true
                break
            fi
        done
        [ "$excluded" = true ] && continue
        
        files+=("$file")
    done < <(if [ "$RECURSIVE" = true ]; then
        find "$TARGET_DIR" -type f
    else
        find "$TARGET_DIR" -maxdepth 1 -type f
    fi)
    
    # Check for conflicts
    if ! check_conflicts "${files[@]}"; then
        log_message "ERROR" "Aborting due to naming conflicts"
        exit 1
    fi
    
    # Preview changes if requested
    if [ "$PREVIEW" = true ]; then
        preview_changes "${files[@]}"
        return
    fi
    
    # Initialize undo file
    if [ -n "$UNDO_FILE" ]; then
        echo "# Undo information for bulk rename operation $(date)" > "$UNDO_FILE"
    fi
    
    # Process files
    for file in "${files[@]}"; do
        local new_name=$(generate_new_name "$file" "$counter")
        
        if [ "$file" = "$new_name" ]; then
            log_message "SKIP" "No change needed: $file"
            ((skipped++))
            continue
        fi
        
        if [ "$DRY_RUN" = true ]; then
            echo "Would rename: $file -> $new_name"
        else
            if mv "$file" "$new_name"; then
                log_message "INFO" "Renamed: $file -> $new_name"
                save_undo_info "$file" "$new_name"
                ((renamed++))
            else
                log_message "ERROR" "Failed to rename: $file"
                ((errors++))
            fi
        fi
        
        ((counter++))
    done
    
    echo
    echo "Summary:"
    echo "--------"
    echo "Files renamed: $renamed"
    echo "Files skipped: $skipped"
    echo "Errors: $errors"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            RENAME_MODE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -e|--exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -H|--hidden)
            INCLUDE_HIDDEN=true
            shift
            ;;
        -L|--follow-links)
            FOLLOW_LINKS=true
            shift
            ;;
        -E|--no-ext)
            PRESERVE_EXT=false
            shift
            ;;
        -n|--start)
            START_NUMBER="$2"
            shift 2
            ;;
        -p|--padding)
            NUMBER_PADDING="$2"
            shift 2
            ;;
        -f|--date-format)
            DATE_FORMAT="$2"
            shift 2
            ;;
        -c|--case)
            CASE_MODE="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --preview)
            PREVIEW=true
            shift
            ;;
        --undo)
            UNDO_FILE="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$TARGET_DIR" ]; then
                TARGET_DIR="$1"
            elif [ -z "$PATTERN" ]; then
                PATTERN="$1"
            elif [ -z "$REPLACEMENT" ]; then
                REPLACEMENT="$1"
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
if [ -z "$TARGET_DIR" ]; then
    echo "Error: Target directory is required"
    print_usage
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory does not exist: $TARGET_DIR"
    exit 1
fi

if [ "$RENAME_MODE" = "pattern" ] && { [ -z "$PATTERN" ] || [ -z "$REPLACEMENT" ]; }; then
    echo "Error: Pattern and replacement are required for pattern mode"
    exit 1
fi

# Initialize log file
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Start renaming
log_message "INFO" "Starting bulk rename operation..."
log_message "INFO" "Target directory: $TARGET_DIR"
log_message "INFO" "Rename mode: $RENAME_MODE"

rename_files

log_message "INFO" "Bulk rename operation completed."
