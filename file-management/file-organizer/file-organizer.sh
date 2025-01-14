#!/bin/bash

# file-organizer.sh
# Advanced file organization tool with multiple organization strategies
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
SOURCE_DIR=""
TARGET_DIR=""
ORGANIZE_BY="type"  # type, date, size, name
DRY_RUN=false
RECURSIVE=false
MOVE_FILES=false
CREATE_LINKS=false
EXCLUDE_PATTERNS=()
INCLUDE_HIDDEN=false
FOLLOW_LINKS=false
PRESERVE_STRUCTURE=false
LOG_FILE=""
CONFLICT_STRATEGY="rename"  # rename, skip, overwrite
DATE_FORMAT="%Y/%m/%d"
SIZE_RANGES=("0:1M:small" "1M:100M:medium" "100M:1G:large" "1G::huge")

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] SOURCE_DIR [TARGET_DIR]"
    echo
    echo "Options:"
    echo "  -o, --organize-by TYPE Organization type (type|date|size|name)"
    echo "  -d, --dry-run        Show what would be done"
    echo "  -r, --recursive      Process directories recursively"
    echo "  -m, --move          Move files instead of copying"
    echo "  -l, --link          Create symbolic links"
    echo "  -e, --exclude PAT    Exclude pattern (can be used multiple times)"
    echo "  -H, --hidden         Include hidden files"
    echo "  -L, --follow-links   Follow symbolic links"
    echo "  -p, --preserve       Preserve directory structure"
    echo "  -c, --conflict STR   Conflict resolution (rename|skip|overwrite)"
    echo "  --date-format FMT    Date format for date-based organization"
    echo "  --log FILE          Log file path"
    echo "  -h, --help           Show this help message"
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

# Function to get file type category
get_file_type() {
    local file="$1"
    local mime_type=$(file --brief --mime-type "$file")
    
    case "$mime_type" in
        image/*)
            echo "images"
            ;;
        video/*)
            echo "videos"
            ;;
        audio/*)
            echo "audio"
            ;;
        application/pdf)
            echo "documents/pdf"
            ;;
        application/msword|application/vnd.openxmlformats-officedocument.*)
            echo "documents/office"
            ;;
        text/plain)
            echo "documents/text"
            ;;
        application/x-compressed|application/x-zip-compressed|application/zip)
            echo "archives"
            ;;
        application/x-executable|application/x-sharedlib)
            echo "executables"
            ;;
        *)
            echo "others"
            ;;
    esac
}

# Function to get size category
get_size_category() {
    local size="$1"
    
    for range in "${SIZE_RANGES[@]}"; do
        IFS=':' read -r min max category <<< "$range"
        
        local min_bytes=0
        [ -n "$min" ] && min_bytes=$(numfmt --from=iec "$min")
        
        if [ -n "$max" ]; then
            local max_bytes=$(numfmt --from=iec "$max")
            if [ "$size" -ge "$min_bytes" ] && [ "$size" -lt "$max_bytes" ]; then
                echo "$category"
                return
            fi
        else
            if [ "$size" -ge "$min_bytes" ]; then
                echo "$category"
                return
            fi
        fi
    done
    
    echo "uncategorized"
}

# Function to get target directory
get_target_dir() {
    local file="$1"
    local base_dir="$2"
    local category=""
    
    case "$ORGANIZE_BY" in
        type)
            category=$(get_file_type "$file")
            ;;
        date)
            category=$(date -r "$file" +"$DATE_FORMAT")
            ;;
        size)
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
            category=$(get_size_category "$size")
            ;;
        name)
            local name=$(basename "$file")
            category="${name:0:1}"
            category="${category^^}"  # Convert to uppercase
            ;;
    esac
    
    if [ "$PRESERVE_STRUCTURE" = true ]; then
        local rel_path=$(realpath --relative-to="$SOURCE_DIR" "$(dirname "$file")")
        echo "$base_dir/$category/$rel_path"
    else
        echo "$base_dir/$category"
    fi
}

# Function to handle file conflicts
handle_conflict() {
    local target="$1"
    
    case "$CONFLICT_STRATEGY" in
        rename)
            local base_dir=$(dirname "$target")
            local base_name=$(basename "$target")
            local name="${base_name%.*}"
            local ext="${base_name##*.}"
            local counter=1
            
            while [ -e "$target" ]; do
                if [ "$name" = "$ext" ]; then
                    target="$base_dir/$name($counter)"
                else
                    target="$base_dir/$name($counter).$ext"
                fi
                ((counter++))
            done
            ;;
        skip)
            if [ -e "$target" ]; then
                return 1
            fi
            ;;
        overwrite)
            # Do nothing, file will be overwritten
            ;;
    esac
    
    echo "$target"
}

# Function to organize files
organize_files() {
    local source="$1"
    local target="$2"
    local processed=0
    local skipped=0
    local errors=0
    
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
        
        # Get target directory and create it if needed
        local target_dir=$(get_target_dir "$file" "$target")
        
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$target_dir"
        fi
        
        # Handle file conflict
        local target_file="$target_dir/$(basename "$file")"
        local final_target=$(handle_conflict "$target_file")
        
        if [ $? -eq 1 ]; then
            log_message "SKIP" "Skipping existing file: $file"
            ((skipped++))
            continue
        fi
        
        if [ "$DRY_RUN" = true ]; then
            if [ "$MOVE_FILES" = true ]; then
                echo "Would move: $file -> $final_target"
            elif [ "$CREATE_LINKS" = true ]; then
                echo "Would link: $file -> $final_target"
            else
                echo "Would copy: $file -> $final_target"
            fi
        else
            if [ "$MOVE_FILES" = true ]; then
                mv "$file" "$final_target" && \
                    log_message "INFO" "Moved: $file -> $final_target" || \
                    { log_message "ERROR" "Failed to move: $file"; ((errors++)); continue; }
            elif [ "$CREATE_LINKS" = true ]; then
                ln -s "$(realpath "$file")" "$final_target" && \
                    log_message "INFO" "Linked: $file -> $final_target" || \
                    { log_message "ERROR" "Failed to link: $file"; ((errors++)); continue; }
            else
                cp -a "$file" "$final_target" && \
                    log_message "INFO" "Copied: $file -> $final_target" || \
                    { log_message "ERROR" "Failed to copy: $file"; ((errors++)); continue; }
            fi
        fi
        
        ((processed++))
    done < <(if [ "$RECURSIVE" = true ]; then
        find "$source" -type f
    else
        find "$source" -maxdepth 1 -type f
    fi)
    
    echo
    echo "Summary:"
    echo "--------"
    echo "Files processed: $processed"
    echo "Files skipped: $skipped"
    echo "Errors: $errors"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--organize-by)
            ORGANIZE_BY="$2"
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
        -m|--move)
            MOVE_FILES=true
            shift
            ;;
        -l|--link)
            CREATE_LINKS=true
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
        -p|--preserve)
            PRESERVE_STRUCTURE=true
            shift
            ;;
        -c|--conflict)
            CONFLICT_STRATEGY="$2"
            shift 2
            ;;
        --date-format)
            DATE_FORMAT="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$SOURCE_DIR" ]; then
                SOURCE_DIR="$1"
            elif [ -z "$TARGET_DIR" ]; then
                TARGET_DIR="$1"
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
if [ -z "$SOURCE_DIR" ]; then
    echo "Error: Source directory is required"
    print_usage
    exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$SOURCE_DIR/organized"
fi

if [ "$MOVE_FILES" = true ] && [ "$CREATE_LINKS" = true ]; then
    echo "Error: Cannot use both move and link options"
    exit 1
fi

# Initialize log file
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Start organization
log_message "INFO" "Starting file organization..."
log_message "INFO" "Source: $SOURCE_DIR"
log_message "INFO" "Target: $TARGET_DIR"
log_message "INFO" "Organization type: $ORGANIZE_BY"

organize_files "$SOURCE_DIR" "$TARGET_DIR"

log_message "INFO" "File organization completed."
