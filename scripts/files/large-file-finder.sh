#!/bin/bash

# large-file-finder.sh
# Advanced large file locator with sorting and filtering capabilities
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
SEARCH_DIR=""
MIN_SIZE="100M"
MAX_SIZE=""
OUTPUT_FORMAT="text"
EXPORT_CSV=""
JSON_OUTPUT=""
SORT_ORDER="desc"
LIMIT=10
EXCLUDE_PATTERNS=()
INCLUDE_HIDDEN=false
FOLLOW_LINKS=false
GROUP_BY=""
LOG_FILE=""
INCLUDE_TYPES=()
EXCLUDE_TYPES=()

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] DIRECTORY"
    echo
    echo "Options:"
    echo "  -s, --min-size SIZE   Minimum file size (e.g., 100M, 1G)"
    echo "  -S, --max-size SIZE   Maximum file size"
    echo "  -f, --format FORMAT   Output format (text|json|csv)"
    echo "  -o, --output FILE     Export results to CSV"
    echo "  -j, --json FILE      Export results to JSON"
    echo "  -n, --limit NUM      Limit number of results"
    echo "  -r, --reverse        Sort in ascending order"
    echo "  -e, --exclude PAT    Exclude pattern (can be used multiple times)"
    echo "  -t, --type TYPE      Include file type (can be used multiple times)"
    echo "  -T, --exclude-type T Exclude file type"
    echo "  -g, --group-by FIELD Group by (type|dir)"
    echo "  -H, --hidden         Include hidden files"
    echo "  -L, --follow-links   Follow symbolic links"
    echo "  -l, --log FILE       Log file path"
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

# Function to convert size to bytes
size_to_bytes() {
    local size="$1"
    local value=$(echo "$size" | sed 's/[^0-9.]//g')
    local unit=$(echo "$size" | sed 's/[0-9.]//g')
    
    case "${unit^^}" in
        B|"")
            echo "${value%.*}"
            ;;
        K|KB)
            echo "$((${value%.*} * 1024))"
            ;;
        M|MB)
            echo "$((${value%.*} * 1024 * 1024))"
            ;;
        G|GB)
            echo "$((${value%.*} * 1024 * 1024 * 1024))"
            ;;
        T|TB)
            echo "$((${value%.*} * 1024 * 1024 * 1024 * 1024))"
            ;;
        *)
            echo "Error: Invalid size unit: $unit"
            exit 1
            ;;
    esac
}

# Function to format file size
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ "$size" -ge 1024 ] && [ "$unit" -lt 4 ]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "$size${units[$unit]}"
}

# Function to get file type
get_file_type() {
    local file="$1"
    file --brief --mime-type "$file"
}

# Function to find large files
find_large_files() {
    local dir="$1"
    local min_bytes=$(size_to_bytes "$MIN_SIZE")
    local max_bytes=""
    [ -n "$MAX_SIZE" ] && max_bytes=$(size_to_bytes "$MAX_SIZE")
    local results=()
    
    log_message "INFO" "Scanning directory: $dir"
    
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
        
        local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
        [ "$size" -lt "$min_bytes" ] && continue
        [ -n "$max_bytes" ] && [ "$size" -gt "$max_bytes" ] && continue
        
        local type=$(get_file_type "$file")
        
        if [ ${#INCLUDE_TYPES[@]} -gt 0 ]; then
            local type_match=false
            for t in "${INCLUDE_TYPES[@]}"; do
                if [[ "$type" == *"$t"* ]]; then
                    type_match=true
                    break
                fi
            done
            [ "$type_match" = false ] && continue
        fi
        
        for t in "${EXCLUDE_TYPES[@]}"; do
            if [[ "$type" == *"$t"* ]]; then
                continue 2
            fi
        done
        
        results+=("$size:$type:$file")
    done < <(find "$dir" -type f)
    
    # Sort results
    if [ "$SORT_ORDER" = "desc" ]; then
        printf '%s\n' "${results[@]}" | sort -t: -k1,1nr | head -n "$LIMIT"
    else
        printf '%s\n' "${results[@]}" | sort -t: -k1,1n | head -n "$LIMIT"
    fi
}

# Function to group results
group_results() {
    local results=("$@")
    local grouped=()
    declare -A groups
    
    case "$GROUP_BY" in
        type)
            for result in "${results[@]}"; do
                IFS=':' read -r size type file <<< "$result"
                groups["$type"]+="$size:$type:$file"$'\n'
            done
            ;;
        dir)
            for result in "${results[@]}"; do
                IFS=':' read -r size type file <<< "$result"
                local dir=$(dirname "$file")
                groups["$dir"]+="$size:$type:$file"$'\n'
            done
            ;;
    esac
    
    for key in "${!groups[@]}"; do
        grouped+=("$key:${groups[$key]}")
    done
    
    echo "${grouped[@]}"
}

# Function to format output
format_output() {
    local results=("$@")
    local total_size=0
    
    case "$OUTPUT_FORMAT" in
        json)
            echo "{"
            if [ -n "$GROUP_BY" ]; then
                echo "  \"groups\": ["
                local first_group=true
                for group in "${results[@]}"; do
                    IFS=':' read -r key data <<< "$group"
                    [ "$first_group" = true ] || echo ","
                    echo "    {"
                    echo "      \"$GROUP_BY\": \"$key\","
                    echo "      \"files\": ["
                    local first_file=true
                    while IFS=':' read -r size type file; do
                        [ -z "$file" ] && continue
                        [ "$first_file" = true ] || echo ","
                        echo "        {"
                        echo "          \"path\": \"$file\","
                        echo "          \"size\": $size,"
                        echo "          \"type\": \"$type\""
                        echo -n "        }"
                        first_file=false
                        total_size=$((total_size + size))
                    done <<< "$data"
                    echo
                    echo "      ]"
                    echo -n "    }"
                    first_group=false
                done
                echo
                echo "  ],"
            else
                echo "  \"files\": ["
                local first=true
                for result in "${results[@]}"; do
                    IFS=':' read -r size type file <<< "$result"
                    [ "$first" = true ] || echo ","
                    echo "    {"
                    echo "      \"path\": \"$file\","
                    echo "      \"size\": $size,"
                    echo "      \"type\": \"$type\""
                    echo -n "    }"
                    first=false
                    total_size=$((total_size + size))
                done
                echo
                echo "  ],"
            fi
            echo "  \"total_size\": $total_size"
            echo "}"
            ;;
        
        csv)
            if [ -n "$GROUP_BY" ]; then
                echo "$GROUP_BY,File,Size,Type"
                for group in "${results[@]}"; do
                    IFS=':' read -r key data <<< "$group"
                    while IFS=':' read -r size type file; do
                        [ -z "$file" ] && continue
                        echo "\"$key\",\"$file\",$(format_size $size),\"$type\""
                        total_size=$((total_size + size))
                    done <<< "$data"
                done
            else
                echo "File,Size,Type"
                for result in "${results[@]}"; do
                    IFS=':' read -r size type file <<< "$result"
                    echo "\"$file\",$(format_size $size),\"$type\""
                    total_size=$((total_size + size))
                done
            fi
            ;;
        
        *)
            echo "Large Files Report"
            echo "================="
            echo
            if [ -n "$GROUP_BY" ]; then
                for group in "${results[@]}"; do
                    IFS=':' read -r key data <<< "$group"
                    echo "Group: $key"
                    echo "------------"
                    while IFS=':' read -r size type file; do
                        [ -z "$file" ] && continue
                        echo "File: $file"
                        echo "Size: $(format_size $size)"
                        echo "Type: $type"
                        echo
                        total_size=$((total_size + size))
                    done <<< "$data"
                done
            else
                for result in "${results[@]}"; do
                    IFS=':' read -r size type file <<< "$result"
                    echo "File: $file"
                    echo "Size: $(format_size $size)"
                    echo "Type: $type"
                    echo
                    total_size=$((total_size + size))
                done
            fi
            echo "Summary"
            echo "-------"
            echo "Total size: $(format_size $total_size)"
            ;;
    esac
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--min-size)
            MIN_SIZE="$2"
            shift 2
            ;;
        -S|--max-size)
            MAX_SIZE="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            EXPORT_CSV="$2"
            shift 2
            ;;
        -j|--json)
            JSON_OUTPUT="$2"
            shift 2
            ;;
        -n|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -r|--reverse)
            SORT_ORDER="asc"
            shift
            ;;
        -e|--exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -t|--type)
            INCLUDE_TYPES+=("$2")
            shift 2
            ;;
        -T|--exclude-type)
            EXCLUDE_TYPES+=("$2")
            shift 2
            ;;
        -g|--group-by)
            GROUP_BY="$2"
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
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$SEARCH_DIR" ]; then
                SEARCH_DIR="$1"
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
if [ -z "$SEARCH_DIR" ]; then
    echo "Error: Search directory is required"
    print_usage
    exit 1
fi

if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Directory does not exist: $SEARCH_DIR"
    exit 1
fi

# Initialize log file
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Find large files
log_message "INFO" "Starting large file search..."
results=($(find_large_files "$SEARCH_DIR"))

# Group results if requested
if [ -n "$GROUP_BY" ]; then
    results=($(group_results "${results[@]}"))
fi

# Format and display/export results
output=$(format_output "${results[@]}")
echo "$output"

if [ -n "$EXPORT_CSV" ]; then
    echo "$output" > "$EXPORT_CSV"
    log_message "INFO" "Results exported to CSV: $EXPORT_CSV"
fi

if [ -n "$JSON_OUTPUT" ]; then
    echo "$output" > "$JSON_OUTPUT"
    log_message "INFO" "Results exported to JSON: $JSON_OUTPUT"
fi

log_message "INFO" "Large file search completed."
