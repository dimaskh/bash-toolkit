#!/bin/bash

# code-format.sh
# Advanced code formatting and style checker
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
LANGUAGE=""
CHECK_ONLY=false
FIX_ISSUES=true
EXCLUDE_PATTERNS=()
CONFIG_FILE=""
REPORT_FILE=""
LOG_FILE=""
VERBOSE=false
PARALLEL=true
MAX_WORKERS=4
STYLE_GUIDE=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] TARGET_DIR"
    echo
    echo "Options:"
    echo "  -l, --language LANG  Language to format (python|js|go|rust)"
    echo "  -c, --check         Check only, don't fix issues"
    echo "  --no-fix            Don't fix issues automatically"
    echo "  -e, --exclude PAT   Exclude pattern (can be used multiple times)"
    echo "  --config FILE       Custom configuration file"
    echo "  -r, --report FILE   Generate report file"
    echo "  --log FILE          Log file path"
    echo "  -v, --verbose       Verbose output"
    echo "  --no-parallel       Disable parallel processing"
    echo "  -w, --workers NUM   Number of parallel workers"
    echo "  -s, --style GUIDE   Style guide to follow"
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
    [ "$VERBOSE" = true ] && echo -e "[$level] ${message}"
}

# Function to detect language
detect_language() {
    local dir="$1"
    
    if [ -f "$dir/package.json" ]; then
        echo "javascript"
    elif [ -f "$dir/requirements.txt" ] || [ -f "$dir/setup.py" ]; then
        echo "python"
    elif [ -f "$dir/go.mod" ]; then
        echo "go"
    elif [ -f "$dir/Cargo.toml" ]; then
        echo "rust"
    else
        echo ""
    fi
}

# Function to check dependencies
check_dependencies() {
    local lang="$1"
    local missing_deps=()
    
    case "$lang" in
        python)
            command -v black >/dev/null 2>&1 || missing_deps+=("black")
            command -v isort >/dev/null 2>&1 || missing_deps+=("isort")
            command -v pylint >/dev/null 2>&1 || missing_deps+=("pylint")
            ;;
        javascript)
            command -v prettier >/dev/null 2>&1 || missing_deps+=("prettier")
            command -v eslint >/dev/null 2>&1 || missing_deps+=("eslint")
            ;;
        go)
            command -v gofmt >/dev/null 2>&1 || missing_deps+=("gofmt")
            command -v goimports >/dev/null 2>&1 || missing_deps+=("goimports")
            ;;
        rust)
            command -v rustfmt >/dev/null 2>&1 || missing_deps+=("rustfmt")
            command -v clippy >/dev/null 2>&1 || missing_deps+=("clippy")
            ;;
    esac
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "ERROR" "Missing dependencies: ${missing_deps[*]}"
        exit 1
    fi
}

# Function to find files to format
find_files() {
    local dir="$1"
    local lang="$2"
    local patterns=()
    
    case "$lang" in
        python)
            patterns+=("*.py")
            ;;
        javascript)
            patterns+=("*.js" "*.jsx" "*.ts" "*.tsx")
            ;;
        go)
            patterns+=("*.go")
            ;;
        rust)
            patterns+=("*.rs")
            ;;
    esac
    
    local find_args=()
    for pattern in "${patterns[@]}"; do
        find_args+=(-o -name "$pattern")
    done
    
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        find_args+=(-not -path "$pattern")
    done
    
    find "$dir" -type f "${find_args[@]}" 2>/dev/null
}

# Function to format Python files
format_python() {
    local file="$1"
    local issues=0
    local output=""
    
    # Run black
    if [ "$CHECK_ONLY" = true ]; then
        if ! black --check "$file" 2>/dev/null; then
            log_message "ERROR" "Black formatting issues in: $file"
            ((issues++))
        fi
    elif [ "$FIX_ISSUES" = true ]; then
        black "$file" 2>/dev/null
    fi
    
    # Run isort
    if [ "$CHECK_ONLY" = true ]; then
        if ! isort --check-only "$file" 2>/dev/null; then
            log_message "ERROR" "Import sorting issues in: $file"
            ((issues++))
        fi
    elif [ "$FIX_ISSUES" = true ]; then
        isort "$file" 2>/dev/null
    fi
    
    # Run pylint
    output=$(pylint "$file" 2>/dev/null || true)
    if [ -n "$output" ]; then
        log_message "WARNING" "Pylint issues in: $file"
        echo "$output" >> "$REPORT_FILE"
        ((issues++))
    fi
    
    return $issues
}

# Function to format JavaScript files
format_javascript() {
    local file="$1"
    local issues=0
    local output=""
    
    # Run prettier
    if [ "$CHECK_ONLY" = true ]; then
        if ! prettier --check "$file" 2>/dev/null; then
            log_message "ERROR" "Prettier formatting issues in: $file"
            ((issues++))
        fi
    elif [ "$FIX_ISSUES" = true ]; then
        prettier --write "$file" 2>/dev/null
    fi
    
    # Run eslint
    if [ "$CHECK_ONLY" = true ]; then
        output=$(eslint "$file" 2>/dev/null || true)
        if [ -n "$output" ]; then
            log_message "ERROR" "ESLint issues in: $file"
            echo "$output" >> "$REPORT_FILE"
            ((issues++))
        fi
    elif [ "$FIX_ISSUES" = true ]; then
        eslint --fix "$file" 2>/dev/null || true
    fi
    
    return $issues
}

# Function to format Go files
format_go() {
    local file="$1"
    local issues=0
    local output=""
    
    # Run gofmt
    if [ "$CHECK_ONLY" = true ]; then
        if ! gofmt -l "$file" | grep -q .; then
            log_message "ERROR" "Gofmt formatting issues in: $file"
            ((issues++))
        fi
    elif [ "$FIX_ISSUES" = true ]; then
        gofmt -w "$file"
    fi
    
    # Run goimports
    if [ "$CHECK_ONLY" = true ]; then
        if ! goimports -l "$file" | grep -q .; then
            log_message "ERROR" "Goimports formatting issues in: $file"
            ((issues++))
        fi
    elif [ "$FIX_ISSUES" = true ]; then
        goimports -w "$file"
    fi
    
    return $issues
}

# Function to format Rust files
format_rust() {
    local file="$1"
    local issues=0
    local output=""
    
    # Run rustfmt
    if [ "$CHECK_ONLY" = true ]; then
        if ! rustfmt --check "$file" 2>/dev/null; then
            log_message "ERROR" "Rustfmt formatting issues in: $file"
            ((issues++))
        fi
    elif [ "$FIX_ISSUES" = true ]; then
        rustfmt "$file"
    fi
    
    # Run clippy
    output=$(cargo clippy --manifest-path="$(dirname "$file")/Cargo.toml" 2>/dev/null || true)
    if [ -n "$output" ]; then
        log_message "WARNING" "Clippy issues in: $file"
        echo "$output" >> "$REPORT_FILE"
        ((issues++))
    fi
    
    return $issues
}

# Function to format a single file
format_file() {
    local file="$1"
    local lang="$2"
    local issues=0
    
    log_message "INFO" "Processing: $file"
    
    case "$lang" in
        python)
            format_python "$file"
            issues=$?
            ;;
        javascript)
            format_javascript "$file"
            issues=$?
            ;;
        go)
            format_go "$file"
            issues=$?
            ;;
        rust)
            format_rust "$file"
            issues=$?
            ;;
    esac
    
    return $issues
}

# Function to process files in parallel
process_files() {
    local files=("$@")
    local total_issues=0
    
    if [ "$PARALLEL" = true ] && [ ${#files[@]} -gt 1 ]; then
        # Process files in parallel using xargs
        printf "%s\n" "${files[@]}" | xargs -P "$MAX_WORKERS" -I {} bash -c "format_file {} \"$LANGUAGE\"" || total_issues=$?
    else
        # Process files sequentially
        for file in "${files[@]}"; do
            format_file "$file" "$LANGUAGE"
            total_issues=$((total_issues + $?))
        done
    fi
    
    return $total_issues
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--language)
            LANGUAGE="$2"
            shift 2
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        --no-fix)
            FIX_ISSUES=false
            shift
            ;;
        -e|--exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -r|--report)
            REPORT_FILE="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --no-parallel)
            PARALLEL=false
            shift
            ;;
        -w|--workers)
            MAX_WORKERS="$2"
            shift 2
            ;;
        -s|--style)
            STYLE_GUIDE="$2"
            shift 2
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            if [ -z "$TARGET_DIR" ]; then
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
if [ -z "$TARGET_DIR" ]; then
    echo "Error: Target directory is required"
    print_usage
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory does not exist: $TARGET_DIR"
    exit 1
fi

# Auto-detect language if not specified
if [ -z "$LANGUAGE" ]; then
    LANGUAGE=$(detect_language "$TARGET_DIR")
    if [ -z "$LANGUAGE" ]; then
        echo "Error: Could not detect language. Please specify with --language"
        exit 1
    fi
    log_message "INFO" "Detected language: $LANGUAGE"
fi

# Initialize log and report files
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

if [ -n "$REPORT_FILE" ]; then
    echo "Code Format Report - $(date)" > "$REPORT_FILE"
    echo "==========================" >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"
fi

# Check dependencies
check_dependencies "$LANGUAGE"

# Find files to format
mapfile -t files < <(find_files "$TARGET_DIR" "$LANGUAGE")

if [ ${#files[@]} -eq 0 ]; then
    log_message "WARNING" "No files found to format"
    exit 0
fi

log_message "INFO" "Found ${#files[@]} files to process"

# Process files
total_issues=$(process_files "${files[@]}")

# Print summary
echo
echo "Summary:"
echo "--------"
echo "Files processed: ${#files[@]}"
echo "Issues found: $total_issues"
if [ -n "$REPORT_FILE" ]; then
    echo "Report saved to: $REPORT_FILE"
fi

# Exit with status
[ "$total_issues" -eq 0 ] || exit 1
