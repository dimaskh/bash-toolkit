#!/bin/bash

# dep-checker.sh
# Project dependency analysis and management script
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
LOG_FILE="$HOME/.dep-checker-$(date +%Y%m%d).log"

# Default values
PROJECT_DIR="."
CHECK_UPDATES=false
SECURITY_CHECK=false
INTERACTIVE=false
VERBOSE=false
OUTPUT_FORMAT="text"
EXCLUDE_PATTERNS=()
MAX_DEPTH=3

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] [PROJECT_DIR]"
    echo
    echo "Options:"
    echo "  -u, --updates          Check for available updates"
    echo "  -s, --security         Perform security vulnerability check"
    echo "  -i, --interactive      Interactive mode for updates"
    echo "  -f, --format FORMAT    Output format (text|json|csv)"
    echo "  -e, --exclude PATTERN  Exclude paths matching pattern"
    echo "  -m, --max-depth N      Maximum search depth (default: 3)"
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

# Function to detect project type
detect_project_type() {
    local dir="$1"
    
    if [ -f "$dir/package.json" ]; then
        echo "nodejs"
    elif [ -f "$dir/requirements.txt" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/Pipfile" ]; then
        echo "python"
    elif [ -f "$dir/go.mod" ]; then
        echo "go"
    elif [ -f "$dir/pom.xml" ] || [ -f "$dir/build.gradle" ]; then
        echo "java"
    elif [ -f "$dir/Gemfile" ]; then
        echo "ruby"
    elif [ -f "$dir/composer.json" ]; then
        echo "php"
    else
        echo "unknown"
    fi
}

# Function to check Node.js dependencies
check_nodejs_deps() {
    local dir="$1"
    
    log_message "INFO" "Checking Node.js dependencies in $dir"
    
    if [ ! -f "$dir/package.json" ]; then
        log_message "ERROR" "No package.json found in $dir"
        return 1
    fi
    
    # Check installed dependencies
    if [ -d "$dir/node_modules" ]; then
        echo -e "\n${BLUE}Installed Dependencies:${NC}"
        npm list --depth=0 2>/dev/null || true
    fi
    
    # Check for updates
    if [ "$CHECK_UPDATES" = true ]; then
        echo -e "\n${YELLOW}Available Updates:${NC}"
        npm outdated || true
    fi
    
    # Security check
    if [ "$SECURITY_CHECK" = true ]; then
        echo -e "\n${RED}Security Vulnerabilities:${NC}"
        npm audit || true
    fi
}

# Function to check Python dependencies
check_python_deps() {
    local dir="$1"
    
    log_message "INFO" "Checking Python dependencies in $dir"
    
    # Check for different Python dependency files
    if [ -f "$dir/requirements.txt" ]; then
        echo -e "\n${BLUE}Requirements.txt Dependencies:${NC}"
        cat "$dir/requirements.txt"
        
        if [ "$CHECK_UPDATES" = true ]; then
            echo -e "\n${YELLOW}Checking for updates...${NC}"
            pip list --outdated 2>/dev/null || true
        fi
    elif [ -f "$dir/Pipfile" ]; then
        echo -e "\n${BLUE}Pipenv Dependencies:${NC}"
        pipenv graph 2>/dev/null || true
        
        if [ "$CHECK_UPDATES" = true ]; then
            echo -e "\n${YELLOW}Checking for updates...${NC}"
            pipenv update --outdated 2>/dev/null || true
        fi
    fi
    
    # Security check
    if [ "$SECURITY_CHECK" = true ]; then
        echo -e "\n${RED}Security Vulnerabilities:${NC}"
        safety check 2>/dev/null || true
    fi
}

# Function to check Go dependencies
check_go_deps() {
    local dir="$1"
    
    log_message "INFO" "Checking Go dependencies in $dir"
    
    if [ ! -f "$dir/go.mod" ]; then
        log_message "ERROR" "No go.mod found in $dir"
        return 1
    fi
    
    echo -e "\n${BLUE}Go Dependencies:${NC}"
    go list -m all 2>/dev/null || true
    
    if [ "$CHECK_UPDATES" = true ]; then
        echo -e "\n${YELLOW}Available Updates:${NC}"
        go list -u -m all 2>/dev/null || true
    fi
}

# Function to check Java dependencies
check_java_deps() {
    local dir="$1"
    
    log_message "INFO" "Checking Java dependencies in $dir"
    
    if [ -f "$dir/pom.xml" ]; then
        echo -e "\n${BLUE}Maven Dependencies:${NC}"
        mvn dependency:tree -DoutputType=text 2>/dev/null || true
        
        if [ "$CHECK_UPDATES" = true ]; then
            echo -e "\n${YELLOW}Available Updates:${NC}"
            mvn versions:display-dependency-updates 2>/dev/null || true
        fi
    elif [ -f "$dir/build.gradle" ]; then
        echo -e "\n${BLUE}Gradle Dependencies:${NC}"
        gradle dependencies 2>/dev/null || true
    fi
}

# Function to check Ruby dependencies
check_ruby_deps() {
    local dir="$1"
    
    log_message "INFO" "Checking Ruby dependencies in $dir"
    
    if [ ! -f "$dir/Gemfile" ]; then
        log_message "ERROR" "No Gemfile found in $dir"
        return 1
    fi
    
    echo -e "\n${BLUE}Ruby Dependencies:${NC}"
    bundle list 2>/dev/null || true
    
    if [ "$CHECK_UPDATES" = true ]; then
        echo -e "\n${YELLOW}Available Updates:${NC}"
        bundle outdated 2>/dev/null || true
    fi
}

# Function to check PHP dependencies
check_php_deps() {
    local dir="$1"
    
    log_message "INFO" "Checking PHP dependencies in $dir"
    
    if [ ! -f "$dir/composer.json" ]; then
        log_message "ERROR" "No composer.json found in $dir"
        return 1
    fi
    
    echo -e "\n${BLUE}PHP Dependencies:${NC}"
    composer show 2>/dev/null || true
    
    if [ "$CHECK_UPDATES" = true ]; then
        echo -e "\n${YELLOW}Available Updates:${NC}"
        composer outdated 2>/dev/null || true
    fi
    
    if [ "$SECURITY_CHECK" = true ]; then
        echo -e "\n${RED}Security Vulnerabilities:${NC}"
        composer audit 2>/dev/null || true
    fi
}

# Function to format output
format_output() {
    local content="$1"
    
    case "$OUTPUT_FORMAT" in
        "json")
            # Convert to JSON format
            echo "$content" | jq -R -s -c 'split("\n")'
            ;;
        "csv")
            # Convert to CSV format
            echo "$content" | sed 's/\t/,/g'
            ;;
        *)
            # Plain text
            echo "$content"
            ;;
    esac
}

# Function to check dependencies recursively
check_deps_recursive() {
    local dir="$1"
    local depth="$2"
    
    if [ "$depth" -gt "$MAX_DEPTH" ]; then
        return
    fi
    
    # Check if directory should be excluded
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$dir" =~ $pattern ]]; then
            return
        fi
    done
    
    # Detect and check project type
    local project_type=$(detect_project_type "$dir")
    
    if [ "$project_type" != "unknown" ]; then
        echo -e "\n${GREEN}=== Checking $dir (${project_type}) ===${NC}"
        
        case "$project_type" in
            "nodejs")
                check_nodejs_deps "$dir"
                ;;
            "python")
                check_python_deps "$dir"
                ;;
            "go")
                check_go_deps "$dir"
                ;;
            "java")
                check_java_deps "$dir"
                ;;
            "ruby")
                check_ruby_deps "$dir"
                ;;
            "php")
                check_php_deps "$dir"
                ;;
        esac
    fi
    
    # Recursively check subdirectories
    while IFS= read -r subdir; do
        check_deps_recursive "$subdir" $((depth + 1))
    done < <(find "$dir" -maxdepth 1 -type d ! -path "$dir" ! -name ".*" ! -name "node_modules" ! -name "venv" ! -name "vendor")
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--updates)
            CHECK_UPDATES=true
            shift
            ;;
        -s|--security)
            SECURITY_CHECK=true
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_PATTERNS+=("$2")
            shift 2
            ;;
        -m|--max-depth)
            MAX_DEPTH="$2"
            shift 2
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
            if [ -d "$1" ]; then
                PROJECT_DIR="$1"
            else
                echo "Error: Invalid option or directory: $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Main execution
log_message "INFO" "Starting dependency check in $PROJECT_DIR"

if [ ! -d "$PROJECT_DIR" ]; then
    log_message "ERROR" "Directory $PROJECT_DIR does not exist"
    exit 1
fi

# Start recursive check
check_deps_recursive "$PROJECT_DIR" 0

log_message "INFO" "Dependency check completed"
echo -e "\n${GREEN}Check complete. See $LOG_FILE for detailed log.${NC}"
