#!/bin/bash

# dev-env-setup.sh
# Local development environment setup automation
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
ENV_TYPE="python"  # python, node, go, rust, etc.
INSTALL_DEPS=true
SETUP_TOOLS=true
SETUP_LINTERS=true
SETUP_FORMATTERS=true
SETUP_DEBUGGER=true
SETUP_IDE=false
IDE_TYPE="vscode"  # vscode, intellij, sublime
VIRTUAL_ENV=true
DOCKER_ENV=false
LOG_FILE=""
INTERACTIVE=false
FORCE=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] PROJECT_DIR"
    echo
    echo "Options:"
    echo "  -t, --type TYPE      Environment type (python|node|go|rust)"
    echo "  --no-deps           Don't install dependencies"
    echo "  --no-tools          Don't setup development tools"
    echo "  --no-linters        Don't setup linters"
    echo "  --no-formatters     Don't setup formatters"
    echo "  --no-debugger       Don't setup debugger"
    echo "  -i, --ide TYPE      Setup IDE (vscode|intellij|sublime)"
    echo "  --no-venv           Don't create virtual environment"
    echo "  -d, --docker        Setup Docker environment"
    echo "  --interactive       Interactive mode"
    echo "  -f, --force         Force setup even if already exists"
    echo "  --log FILE          Log file path"
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

# Function to prompt user for input
prompt_user() {
    local prompt="$1"
    local default="$2"
    local value=""
    
    read -p "$prompt [$default]: " value
    echo "${value:-$default}"
}

# Function to check system dependencies
check_system_deps() {
    local missing_deps=()
    
    case "$ENV_TYPE" in
        python)
            command -v python3 >/dev/null 2>&1 || missing_deps+=("python3")
            command -v pip3 >/dev/null 2>&1 || missing_deps+=("python3-pip")
            ;;
        node)
            command -v node >/dev/null 2>&1 || missing_deps+=("nodejs")
            command -v npm >/dev/null 2>&1 || missing_deps+=("npm")
            ;;
        go)
            command -v go >/dev/null 2>&1 || missing_deps+=("golang")
            ;;
        rust)
            command -v rustc >/dev/null 2>&1 || missing_deps+=("rust")
            command -v cargo >/dev/null 2>&1 || missing_deps+=("cargo")
            ;;
    esac
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "ERROR" "Missing system dependencies: ${missing_deps[*]}"
        log_message "INFO" "Please install them using your system's package manager"
        exit 1
    fi
}

# Function to setup virtual environment
setup_virtual_env() {
    local dir="$1"
    local type="$2"
    
    case "$type" in
        python)
            python3 -m venv "$dir/.venv"
            source "$dir/.venv/bin/activate"
            pip install --upgrade pip setuptools wheel
            ;;
        node)
            # Node uses package.json for environment isolation
            npm init -y
            ;;
        go)
            # Go uses go.mod for dependency management
            go mod init "$(basename "$dir")"
            ;;
        rust)
            # Rust uses Cargo.toml for project management
            cargo init
            ;;
    esac
}

# Function to install dependencies
install_dependencies() {
    local dir="$1"
    local type="$2"
    
    case "$type" in
        python)
            if [ -f "$dir/requirements.txt" ]; then
                pip install -r requirements.txt
            fi
            if [ -f "$dir/setup.py" ]; then
                pip install -e ".[dev]"
            fi
            ;;
        node)
            if [ -f "$dir/package.json" ]; then
                npm install
            fi
            ;;
        go)
            if [ -f "$dir/go.mod" ]; then
                go mod download
            fi
            ;;
        rust)
            if [ -f "$dir/Cargo.toml" ]; then
                cargo build
            fi
            ;;
    esac
}

# Function to setup development tools
setup_dev_tools() {
    local type="$2"
    
    case "$type" in
        python)
            pip install pytest pytest-cov mypy pylint black isort
            ;;
        node)
            npm install -D jest eslint prettier typescript ts-node nodemon
            ;;
        go)
            go install golang.org/x/tools/cmd/goimports@latest
            go install golang.org/x/lint/golint@latest
            go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
            ;;
        rust)
            rustup component add clippy rustfmt
            cargo install cargo-watch cargo-edit cargo-audit
            ;;
    esac
}

# Function to setup IDE configuration
setup_ide_config() {
    local dir="$1"
    local type="$2"
    local ide="$3"
    
    case "$ide" in
        vscode)
            mkdir -p "$dir/.vscode"
            
            # settings.json
            cat > "$dir/.vscode/settings.json" << EOF
{
    "editor.formatOnSave": true,
    "editor.rulers": [80, 100],
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true
}
EOF
            
            # launch.json
            cat > "$dir/.vscode/launch.json" << EOF
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug",
            "type": "${type}",
            "request": "launch",
            "program": "\${workspaceFolder}/src/main.${type}"
        }
    ]
}
EOF
            ;;
            
        intellij)
            mkdir -p "$dir/.idea"
            # Add IntelliJ IDEA configuration files
            ;;
            
        sublime)
            mkdir -p "$dir/.sublime"
            # Add Sublime Text configuration files
            ;;
    esac
}

# Function to setup Docker environment
setup_docker_env() {
    local dir="$1"
    local type="$2"
    
    # Dockerfile
    cat > "$dir/Dockerfile" << EOF
FROM ${type}:latest

WORKDIR /app

COPY . .

RUN ${type}-install-dependencies

CMD ["${type}-start-command"]
EOF
    
    # docker-compose.yml
    cat > "$dir/docker-compose.yml" << EOF
version: '3.8'

services:
  app:
    build: .
    volumes:
      - .:/app
    ports:
      - "8080:8080"
    environment:
      - NODE_ENV=development
EOF
    
    # .dockerignore
    cat > "$dir/.dockerignore" << EOF
.git
.gitignore
.env
*.log
node_modules
__pycache__
*.pyc
.venv
target
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            ENV_TYPE="$2"
            shift 2
            ;;
        --no-deps)
            INSTALL_DEPS=false
            shift
            ;;
        --no-tools)
            SETUP_TOOLS=false
            shift
            ;;
        --no-linters)
            SETUP_LINTERS=false
            shift
            ;;
        --no-formatters)
            SETUP_FORMATTERS=false
            shift
            ;;
        --no-debugger)
            SETUP_DEBUGGER=false
            shift
            ;;
        -i|--ide)
            SETUP_IDE=true
            IDE_TYPE="$2"
            shift 2
            ;;
        --no-venv)
            VIRTUAL_ENV=false
            shift
            ;;
        -d|--docker)
            DOCKER_ENV=true
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
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

# Interactive mode
if [ "$INTERACTIVE" = true ]; then
    PROJECT_DIR=$(prompt_user "Project directory" "${PROJECT_DIR}")
    ENV_TYPE=$(prompt_user "Environment type (python|node|go|rust)" "${ENV_TYPE}")
    INSTALL_DEPS=$(prompt_user "Install dependencies? (true|false)" "${INSTALL_DEPS}")
    SETUP_TOOLS=$(prompt_user "Setup development tools? (true|false)" "${SETUP_TOOLS}")
    SETUP_IDE=$(prompt_user "Setup IDE? (true|false)" "${SETUP_IDE}")
    [ "$SETUP_IDE" = true ] && IDE_TYPE=$(prompt_user "IDE type (vscode|intellij|sublime)" "${IDE_TYPE}")
    VIRTUAL_ENV=$(prompt_user "Create virtual environment? (true|false)" "${VIRTUAL_ENV}")
    DOCKER_ENV=$(prompt_user "Setup Docker environment? (true|false)" "${DOCKER_ENV}")
fi

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

# Initialize log file
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Start setup
log_message "INFO" "Setting up development environment"
log_message "INFO" "Project directory: $PROJECT_DIR"
log_message "INFO" "Environment type: $ENV_TYPE"

# Check system dependencies
check_system_deps

# Setup virtual environment
if [ "$VIRTUAL_ENV" = true ]; then
    log_message "INFO" "Setting up virtual environment..."
    setup_virtual_env "$PROJECT_DIR" "$ENV_TYPE"
fi

# Install dependencies
if [ "$INSTALL_DEPS" = true ]; then
    log_message "INFO" "Installing dependencies..."
    install_dependencies "$PROJECT_DIR" "$ENV_TYPE"
fi

# Setup development tools
if [ "$SETUP_TOOLS" = true ]; then
    log_message "INFO" "Setting up development tools..."
    setup_dev_tools "$PROJECT_DIR" "$ENV_TYPE"
fi

# Setup IDE configuration
if [ "$SETUP_IDE" = true ]; then
    log_message "INFO" "Setting up IDE configuration..."
    setup_ide_config "$PROJECT_DIR" "$ENV_TYPE" "$IDE_TYPE"
fi

# Setup Docker environment
if [ "$DOCKER_ENV" = true ]; then
    log_message "INFO" "Setting up Docker environment..."
    setup_docker_env "$PROJECT_DIR" "$ENV_TYPE"
fi

log_message "INFO" "Development environment setup completed successfully."
echo
echo "Next steps:"
echo "1. Review the installed tools and configurations"
echo "2. Customize IDE settings if needed"
echo "3. Start developing!"
