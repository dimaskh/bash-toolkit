#!/bin/bash

# permission-auditor.sh
# File permission and ownership auditing tool
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
LOG_FILE="$HOME/.permission-audit-$(date +%Y%m%d).log"

# Default values
TARGET_PATH=""
OUTPUT_FORMAT="text"
VERBOSE=false
RECURSIVE=false
SAVE_OUTPUT=false
CHECK_SUID=true
CHECK_SGID=true
CHECK_WORLD_WRITABLE=true
IGNORE_PATTERN=""
CUSTOM_RULES_FILE=""
FIX_PERMISSIONS=false
SHOW_RECOMMENDATIONS=true

# Default permission rules
declare -A PERMISSION_RULES=(
    ["/etc"]="644:root:root"
    ["/etc/shadow"]="400:root:root"
    ["/etc/passwd"]="644:root:root"
    ["/home"]="755:root:root"
    ["/var/log"]="755:root:root"
)

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] PATH"
    echo
    echo "Options:"
    echo "  -r, --recursive        Recursive scan"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  -i, --ignore PATTERN   Ignore pattern (glob)"
    echo "  -c, --custom FILE      Custom rules file"
    echo "  -o, --output FILE      Save results to file"
    echo "  --no-suid             Skip SUID check"
    echo "  --no-sgid             Skip SGID check"
    echo "  --no-world            Skip world-writable check"
    echo "  --fix                 Fix permissions (requires root)"
    echo "  --no-recommend        Skip recommendations"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help message"
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
    local file="$1"
    local perms="$2"
    local owner="$3"
    local group="$4"
    local issue="$5"
    local recommendation="$6"
    
    case "$OUTPUT_FORMAT" in
        "json")
            printf '{"file":"%s","permissions":"%s","owner":"%s","group":"%s","issue":"%s","recommendation":"%s"}\n' \
                "$file" "$perms" "$owner" "$group" "$issue" "$recommendation"
            ;;
        "csv")
            printf '%s,%s,%s,%s,%s,%s\n' \
                "$file" "$perms" "$owner" "$group" "$issue" "$recommendation"
            ;;
        *)
            printf "%-50s %-10s %-8s:%-8s %s\n" "$file" "$perms" "$owner" "$group" "$issue"
            [ -n "$recommendation" ] && printf "  → Recommendation: %s\n" "$recommendation"
            ;;
    esac
}

# Function to check if path matches ignore pattern
is_ignored() {
    local path="$1"
    [ -n "$IGNORE_PATTERN" ] && [[ "$path" == $IGNORE_PATTERN ]]
}

# Function to load custom rules
load_custom_rules() {
    local rules_file="$1"
    if [ -f "$rules_file" ]; then
        while IFS=: read -r path perms owner group || [ -n "$path" ]; do
            [ -z "$path" ] && continue
            [ "${path:0:1}" = "#" ] && continue
            PERMISSION_RULES["$path"]="$perms:$owner:$group"
        done < "$rules_file"
    fi
}

# Function to get recommended permissions
get_recommendation() {
    local file="$1"
    local current_perms="$2"
    local current_owner="$3"
    local current_group="$4"
    
    for rule_path in "${!PERMISSION_RULES[@]}"; do
        if [[ "$file" == $rule_path* ]]; then
            IFS=: read -r rec_perms rec_owner rec_group <<< "${PERMISSION_RULES[$rule_path]}"
            if [ "$current_perms" != "$rec_perms" ] || \
               [ "$current_owner" != "$rec_owner" ] || \
               [ "$current_group" != "$rec_group" ]; then
                echo "Change to ${rec_perms} ${rec_owner}:${rec_group}"
                return
            fi
        fi
    done
    echo ""
}

# Function to fix permissions
fix_permissions() {
    local file="$1"
    local recommendation="$2"
    
    if [ -n "$recommendation" ]; then
        read -r perms owner group <<< "$(echo "$recommendation" | sed 's/Change to \([0-9]*\) \([^:]*\):\(.*\)/\1 \2 \3/')"
        chmod "$perms" "$file" 2>/dev/null || true
        chown "$owner:$group" "$file" 2>/dev/null || true
    fi
}

# Function to check single file
check_file() {
    local file="$1"
    
    # Skip if file matches ignore pattern
    is_ignored "$file" && return
    
    # Get file information
    local perms
    local owner
    local group
    perms=$(stat -c "%a" "$file")
    owner=$(stat -c "%U" "$file")
    group=$(stat -c "%G" "$file")
    
    local issues=()
    local recommendation=""
    
    # Check SUID
    if [ "$CHECK_SUID" = true ] && [ "$((perms & 4000))" -ne 0 ]; then
        issues+=("SUID bit set")
    fi
    
    # Check SGID
    if [ "$CHECK_SGID" = true ] && [ "$((perms & 2000))" -ne 0 ]; then
        issues+=("SGID bit set")
    fi
    
    # Check world-writable
    if [ "$CHECK_WORLD_WRITABLE" = true ] && [ "$((perms & 2))" -ne 0 ]; then
        issues+=("World-writable")
    fi
    
    # Get recommendation if enabled
    if [ "$SHOW_RECOMMENDATIONS" = true ]; then
        recommendation=$(get_recommendation "$file" "$perms" "$owner" "$group")
    fi
    
    # Fix permissions if enabled and recommendation exists
    if [ "$FIX_PERMISSIONS" = true ] && [ -n "$recommendation" ]; then
        fix_permissions "$file" "$recommendation"
        perms=$(stat -c "%a" "$file")
        owner=$(stat -c "%U" "$file")
        group=$(stat -c "%G" "$file")
    fi
    
    # Output if there are issues or recommendations
    if [ ${#issues[@]} -gt 0 ] || [ -n "$recommendation" ]; then
        format_output "$file" "$perms" "$owner" "$group" "${issues[*]}" "$recommendation"
    fi
}

# Function to process directory
process_directory() {
    local dir="$1"
    
    if [ "$RECURSIVE" = true ]; then
        find "$dir" -type f -print0 | while IFS= read -r -d '' file; do
            check_file "$file"
        done
    else
        for file in "$dir"/*; do
            [ -f "$file" ] && check_file "$file"
        done
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -i|--ignore)
            IGNORE_PATTERN="$2"
            shift 2
            ;;
        -c|--custom)
            CUSTOM_RULES_FILE="$2"
            shift 2
            ;;
        -o|--output)
            SAVE_OUTPUT=true
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --no-suid)
            CHECK_SUID=false
            shift
            ;;
        --no-sgid)
            CHECK_SGID=false
            shift
            ;;
        --no-world)
            CHECK_WORLD_WRITABLE=false
            shift
            ;;
        --fix)
            FIX_PERMISSIONS=true
            shift
            ;;
        --no-recommend)
            SHOW_RECOMMENDATIONS=false
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
            if [ -z "$TARGET_PATH" ]; then
                TARGET_PATH="$1"
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
if [ -z "$TARGET_PATH" ]; then
    echo "Error: No target path specified"
    print_usage
    exit 1
fi

# Check if path exists
if [ ! -e "$TARGET_PATH" ]; then
    echo "Error: Path does not exist: $TARGET_PATH"
    exit 1
fi

# Load custom rules if specified
[ -n "$CUSTOM_RULES_FILE" ] && load_custom_rules "$CUSTOM_RULES_FILE"

# Main execution
log_message "INFO" "Starting permission audit"

# Header for text output
if [ "$OUTPUT_FORMAT" = "text" ]; then
    printf "%-50s %-10s %-17s %s\n" "File" "Perms" "Owner:Group" "Issues"
    printf "%s\n" "--------------------------------------------------------------------------------"
fi

if [ -f "$TARGET_PATH" ]; then
    check_file "$TARGET_PATH"
else
    process_directory "$TARGET_PATH"
fi

log_message "INFO" "Permission audit completed"
echo -e "\n${GREEN}Audit complete. See $LOG_FILE for detailed log.${NC}"
