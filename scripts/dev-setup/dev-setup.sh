#!/bin/bash

# dev-setup.sh
# Development environment setup automation script
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
LOG_FILE="$HOME/.dev-setup-$(date +%Y%m%d).log"

# Default values
CONFIG_FILE="$HOME/.dev-setup.conf"
DRY_RUN=false
FORCE=false
VERBOSE=false
COMPONENTS=()
SKIP_COMPONENTS=()

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -c, --config FILE      Use specific config file"
    echo "  -i, --install COMP     Install specific component"
    echo "  -s, --skip COMP       Skip specific component"
    echo "  -l, --list            List available components"
    echo "  -f, --force           Don't ask for confirmation"
    echo "  -d, --dry-run         Show what would be installed"
    echo "  -v, --verbose         Verbose output"
    echo "  -h, --help            Show this help message"
    echo
    echo "Available components:"
    echo "  languages    Programming languages (Python, Node.js, Go, etc.)"
    echo "  tools        Development tools (Git, Docker, VSCode, etc.)"
    echo "  shells       Shell configurations (Zsh, Oh-My-Zsh, etc.)"
    echo "  databases    Databases (PostgreSQL, MongoDB, Redis, etc.)"
    echo "  configs      Configuration files (.gitconfig, .vimrc, etc.)"
    echo "  deps        System dependencies and libraries"
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [$level] - ${message}" >> "$LOG_FILE"
    [ "$VERBOSE" = true ] && echo -e "[$level] ${message}"
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Function to detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null; then
        echo "apt"
    elif command -v dnf >/dev/null; then
        echo "dnf"
    elif command -v yum >/dev/null; then
        echo "yum"
    elif command -v pacman >/dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Function to install system packages
install_packages() {
    local packages=("$@")
    local pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        "apt")
            if [ "$DRY_RUN" = true ]; then
                echo "Would install: ${packages[*]}"
            else
                sudo apt-get update
                sudo apt-get install -y "${packages[@]}"
            fi
            ;;
        "dnf")
            if [ "$DRY_RUN" = true ]; then
                echo "Would install: ${packages[*]}"
            else
                sudo dnf install -y "${packages[@]}"
            fi
            ;;
        "yum")
            if [ "$DRY_RUN" = true ]; then
                echo "Would install: ${packages[*]}"
            else
                sudo yum install -y "${packages[@]}"
            fi
            ;;
        "pacman")
            if [ "$DRY_RUN" = true ]; then
                echo "Would install: ${packages[*]}"
            else
                sudo pacman -S --noconfirm "${packages[@]}"
            fi
            ;;
        *)
            log_message "ERROR" "Unsupported package manager"
            return 1
            ;;
    esac
}

# Function to setup programming languages
setup_languages() {
    log_message "INFO" "Setting up programming languages"
    
    # Python
    if ! command -v python3 >/dev/null; then
        install_packages python3 python3-pip
        if [ "$DRY_RUN" = false ]; then
            python3 -m pip install --user pipenv virtualenv
        fi
    fi
    
    # Node.js
    if ! command -v node >/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            nvm install --lts
            npm install -g yarn
        else
            echo "Would install Node.js via nvm"
        fi
    fi
    
    # Go
    if ! command -v go >/dev/null; then
        install_packages golang
    fi
}

# Function to setup development tools
setup_tools() {
    log_message "INFO" "Setting up development tools"
    
    # Git
    if ! command -v git >/dev/null; then
        install_packages git
    fi
    
    # Docker
    if ! command -v docker >/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker "$USER"
            rm get-docker.sh
        else
            echo "Would install Docker"
        fi
    fi
    
    # VSCode
    if ! command -v code >/dev/null; then
        case $(detect_os) in
            "ubuntu"|"debian")
                if [ "$DRY_RUN" = false ]; then
                    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
                    sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
                    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
                    sudo apt-get update
                    sudo apt-get install -y code
                    rm packages.microsoft.gpg
                else
                    echo "Would install VSCode"
                fi
                ;;
        esac
    fi
}

# Function to setup shell configurations
setup_shells() {
    log_message "INFO" "Setting up shell configurations"
    
    # Zsh
    if ! command -v zsh >/dev/null; then
        install_packages zsh
    fi
    
    # Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ] && [ "$DRY_RUN" = false ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Set Zsh as default shell
    if [ "$SHELL" != "$(which zsh)" ] && [ "$DRY_RUN" = false ]; then
        chsh -s "$(which zsh)"
    fi
}

# Function to setup databases
setup_databases() {
    log_message "INFO" "Setting up databases"
    
    # PostgreSQL
    if ! command -v psql >/dev/null; then
        install_packages postgresql postgresql-contrib
        if [ "$DRY_RUN" = false ]; then
            sudo systemctl enable postgresql
            sudo systemctl start postgresql
        fi
    fi
    
    # MongoDB
    if ! command -v mongod >/dev/null; then
        case $(detect_os) in
            "ubuntu"|"debian")
                if [ "$DRY_RUN" = false ]; then
                    wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | sudo apt-key add -
                    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-5.0.list
                    sudo apt-get update
                    sudo apt-get install -y mongodb-org
                    sudo systemctl enable mongod
                    sudo systemctl start mongod
                else
                    echo "Would install MongoDB"
                fi
                ;;
        esac
    fi
    
    # Redis
    if ! command -v redis-server >/dev/null; then
        install_packages redis-server
        if [ "$DRY_RUN" = false ]; then
            sudo systemctl enable redis-server
            sudo systemctl start redis-server
        fi
    fi
}

# Function to setup configuration files
setup_configs() {
    log_message "INFO" "Setting up configuration files"
    
    # Git configuration
    if [ "$DRY_RUN" = false ]; then
        git config --global core.editor "vim"
        git config --global init.defaultBranch "main"
        git config --global pull.rebase false
    fi
    
    # Vim configuration
    if [ ! -f "$HOME/.vimrc" ] && [ "$DRY_RUN" = false ]; then
        cat > "$HOME/.vimrc" << 'EOL'
syntax on
set number
set expandtab
set tabstop=4
set shiftwidth=4
set autoindent
set smartindent
set ruler
set showcmd
set incsearch
set hlsearch
EOL
    fi
    
    # SSH configuration
    if [ ! -f "$HOME/.ssh/config" ] && [ "$DRY_RUN" = false ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        cat > "$HOME/.ssh/config" << 'EOL'
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 30
    StrictHostKeyChecking ask
    IdentitiesOnly yes
EOL
        chmod 600 "$HOME/.ssh/config"
    fi
}

# Function to setup system dependencies
setup_deps() {
    log_message "INFO" "Setting up system dependencies"
    
    local common_deps=(
        build-essential
        curl
        wget
        vim
        htop
        tmux
        tree
        jq
        unzip
    )
    
    install_packages "${common_deps[@]}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -i|--install)
            COMPONENTS+=("$2")
            shift 2
            ;;
        -s|--skip)
            SKIP_COMPONENTS+=("$2")
            shift 2
            ;;
        -l|--list)
            print_usage
            exit 0
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -d|--dry-run)
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
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Main execution
log_message "INFO" "Starting development environment setup"

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# If no components specified, setup everything
if [ ${#COMPONENTS[@]} -eq 0 ]; then
    COMPONENTS=(languages tools shells databases configs deps)
fi

# Setup each component
for component in "${COMPONENTS[@]}"; do
    if [[ ! " ${SKIP_COMPONENTS[@]} " =~ " ${component} " ]]; then
        case "$component" in
            languages)
                setup_languages
                ;;
            tools)
                setup_tools
                ;;
            shells)
                setup_shells
                ;;
            databases)
                setup_databases
                ;;
            configs)
                setup_configs
                ;;
            deps)
                setup_deps
                ;;
            *)
                log_message "WARNING" "Unknown component: $component"
                ;;
        esac
    fi
done

log_message "INFO" "Setup completed"
echo -e "\n${GREEN}Setup complete. Check $LOG_FILE for detailed log.${NC}"
echo -e "${YELLOW}Note: Some changes may require a system restart.${NC}"
