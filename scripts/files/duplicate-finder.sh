#!/bin/bash

# duplicate-finder.sh
# Advanced duplicate file finder with multiple hash algorithms and reporting
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
MIN_SIZE=1
HASH_ALGORITHM="sha256"
OUTPUT_FORMAT="text"
EXPORT_CSV=""
JSON_OUTPUT=""
INTERACTIVE=false
AUTO_DELETE=false
EXCLUDE_PATTERNS=()
INCLUDE_HIDDEN=false
FOLLOW_LINKS=false
VERIFY_CONTENT=false
LOG_FILE=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] DIRECTORY"
    echo
    echo "Options:"
    echo "  -s, --min-size SIZE   Minimum file size (bytes)"
    echo "  -a, --algorithm ALG   Hash algorithm (md5|sha1|sha256|sha512)"
    echo "  -f, --format FORMAT   Output format (text|json|csv)"
    echo "  -o, --output FILE     Export results to CSV"
    echo "  -j, --json FILE      Export results to JSON"
    echo "  -i, --interactive    Interactive mode for deletion"
    echo "  -d, --auto-delete    Automatically delete duplicates"
    echo "  -e, --exclude PAT    Exclude pattern (can be used multiple times)"
    echo "  -H, --hidden         Include hidden files"
    echo "  -L, --follow-links   Follow symbolic links"
    echo "  -v, --verify         Verify file contents"
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

# Function to calculate file hash
calculate_hash() {
    local file="$1"
    case "$HASH_ALGORITHM" in
        md5)
            md5sum "$file" | cut -d' ' -f1
            ;;
        sha1)
            sha1sum "$file" | cut -d' ' -f1
            ;;
        sha256)
            sha256sum "$file" | cut -d' ' -f1
            ;;
        sha512)
            sha512sum "$file" | cut -d' ' -f1
            ;;
    esac
}

# Function to verify file contents
verify_files() {
    local file1="$1"
    local file2="$2"
    cmp -s "$file1" "$file2"
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

# Function to find duplicate files
find_duplicates() {
    local dir="$1"
    local temp_db=$(mktemp)
    local result=()
    declare -A size_groups
    declare -A hash_groups
    
    log_message "INFO" "Scanning directory: $dir"
    
    # Find all files and group by size
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
        [ "$size" -lt "$MIN_SIZE" ] && continue
        
        size_groups["$size"]="${size_groups["$size"]}:$file"
    done < <(find "$dir" -type f)
    
    # Process files by size groups
    for size in "${!size_groups[@]}"; do
        IFS=':' read -ra files <<< "${size_groups[$size]}"
        [ "${#files[@]}" -le 1 ] && continue
        
        # Calculate hashes for files in the same size group
        for file in "${files[@]}"; do
            [ -z "$file" ] && continue
            local hash=$(calculate_hash "$file")
            hash_groups["$hash"]="${hash_groups["$hash"]}:$file"
        done
    done
    
    # Process duplicate files
    for hash in "${!hash_groups[@]}"; do
        IFS=':' read -ra files <<< "${hash_groups[$hash]}"
        [ "${#files[@]}" -le 1 ] && continue
        
        local group=()
        local first_file=""
        
        for file in "${files[@]}"; do
            [ -z "$file" ] && continue
            
            if [ -z "$first_file" ]; then
                first_file="$file"
                group+=("$file")
                continue
            fi
            
            if [ "$VERIFY_CONTENT" = true ]; then
                if verify_files "$first_file" "$file"; then
                    group+=("$file")
                fi
            else
                group+=("$file")
            fi
        done
        
        [ "${#group[@]}" -le 1 ] && continue
        result+=("${group[*]}")
    done
    
    echo "${result[@]}"
}

# Function to format output
format_output() {
    local duplicates=("$@")
    local group_count=0
    local total_size=0
    
    case "$OUTPUT_FORMAT" in
        json)
            echo "{"
            echo "  \"groups\": ["
            for group in "${duplicates[@]}"; do
                [ "$group_count" -gt 0 ] && echo ","
                echo "    {"
                echo "      \"files\": ["
                local first=true
                for file in $group; do
                    [ "$first" = true ] || echo ","
                    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
                    echo "        {"
                    echo "          \"path\": \"$file\","
                    echo "          \"size\": $size,"
                    echo "          \"hash\": \"$(calculate_hash "$file")\""
                    echo -n "        }"
                    first=false
                    total_size=$((total_size + size))
                done
                echo
                echo "      ]"
                echo -n "    }"
                ((group_count++))
            done
            echo
            echo "  ],"
            echo "  \"total_groups\": $group_count,"
            echo "  \"total_size\": $total_size"
            echo "}"
            ;;
        
        csv)
            echo "Group,File,Size,Hash"
            local group_num=1
            for group in "${duplicates[@]}"; do
                for file in $group; do
                    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
                    echo "$group_num,\"$file\",$(format_size $size),$(calculate_hash "$file")"
                    total_size=$((total_size + size))
                done
                ((group_num++))
            done
            ;;
        
        *)
            echo "Duplicate Files Report"
            echo "====================="
            echo
            local group_num=1
            for group in "${duplicates[@]}"; do
                echo "Group $group_num:"
                echo "------------"
                for file in $group; do
                    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
                    echo "File: $file"
                    echo "Size: $(format_size $size)"
                    echo "Hash: $(calculate_hash "$file")"
                    echo
                    total_size=$((total_size + size))
                done
                ((group_num++))
            done
            echo "Summary"
            echo "-------"
            echo "Total duplicate groups: $((group_num - 1))"
            echo "Total wasted space: $(format_size $total_size)"
            ;;
    esac
}

# Function to handle interactive deletion
handle_interactive_deletion() {
    local duplicates=("$@")
    local group_num=1
    
    for group in "${duplicates[@]}"; do
        echo
        echo "Group $group_num:"
        echo "------------"
        local file_num=1
        declare -a files
        
        for file in $group; do
            files+=("$file")
            echo "[$file_num] $file ($(format_size $(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")))"
            ((file_num++))
        done
        
        echo
        echo "Select files to delete (space-separated numbers, 's' to skip): "
        read -r selection
        
        if [ "$selection" != "s" ]; then
            for num in $selection; do
                if [ "$num" -ge 1 ] && [ "$num" -lt "$file_num" ]; then
                    rm -f "${files[$((num-1))]}"
                    log_message "INFO" "Deleted: ${files[$((num-1))]}"
                fi
            done
        fi
        
        ((group_num++))
    done
}

# Function to handle automatic deletion
handle_auto_deletion() {
    local duplicates=("$@")
    local total_saved=0
    
    for group in "${duplicates[@]}"; do
        local first=true
        for file in $group; do
            if [ "$first" = true ]; then
                first=false
                continue
            fi
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file")
            total_saved=$((total_saved + size))
            rm -f "$file"
            log_message "INFO" "Deleted: $file"
        done
    done
    
    log_message "INFO" "Total space saved: $(format_size $total_saved)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--min-size)
            MIN_SIZE="$2"
            shift 2
            ;;
        -a|--algorithm)
            HASH_ALGORITHM="$2"
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
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -d|--auto-delete)
            AUTO_DELETE=true
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
        -v|--verify)
            VERIFY_CONTENT=true
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

if [ "$INTERACTIVE" = true ] && [ "$AUTO_DELETE" = true ]; then
    echo "Error: Cannot use both interactive and auto-delete modes"
    exit 1
fi

# Initialize log file
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Find duplicates
log_message "INFO" "Starting duplicate file search..."
duplicates=($(find_duplicates "$SEARCH_DIR"))

# Handle results
if [ ${#duplicates[@]} -eq 0 ]; then
    log_message "INFO" "No duplicate files found."
    exit 0
fi

# Format and display/export results
output=$(format_output "${duplicates[@]}")
echo "$output"

if [ -n "$EXPORT_CSV" ]; then
    echo "$output" > "$EXPORT_CSV"
    log_message "INFO" "Results exported to CSV: $EXPORT_CSV"
fi

if [ -n "$JSON_OUTPUT" ]; then
    echo "$output" > "$JSON_OUTPUT"
    log_message "INFO" "Results exported to JSON: $JSON_OUTPUT"
fi

# Handle deletion if requested
if [ "$INTERACTIVE" = true ]; then
    handle_interactive_deletion "${duplicates[@]}"
elif [ "$AUTO_DELETE" = true ]; then
    handle_auto_deletion "${duplicates[@]}"
fi

log_message "INFO" "Duplicate file search completed."
