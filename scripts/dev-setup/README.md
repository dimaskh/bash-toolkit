# Development Environment Setup Script

An advanced script for automating the setup of a complete development environment, including programming languages, tools, databases, and configurations.

## Features

- Component-based installation:
  - Programming languages (Python, Node.js, Go)
  - Development tools (Git, Docker, VSCode)
  - Shell configurations (Zsh, Oh-My-Zsh)
  - Databases (PostgreSQL, MongoDB, Redis)
  - Configuration files (.gitconfig, .vimrc, .ssh/config)
  - System dependencies
- Multi-distribution support
- Configuration file support
- Selective component installation
- Component skipping
- Dry-run mode
- Detailed logging
- Force mode for automation

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x dev-setup.sh
```

2. Optionally create a configuration file:
```bash
touch ~/.dev-setup.conf
```

## Usage

```bash
./dev-setup.sh [OPTIONS]
```

### Options

- `-c, --config FILE`      Use specific config file
- `-i, --install COMP`     Install specific component
- `-s, --skip COMP`       Skip specific component
- `-l, --list`            List available components
- `-f, --force`           Don't ask for confirmation
- `-d, --dry-run`         Show what would be installed
- `-v, --verbose`         Verbose output
- `-h, --help`            Show this help message

### Available Components

- `languages`    Programming languages (Python, Node.js, Go)
- `tools`        Development tools (Git, Docker, VSCode)
- `shells`       Shell configurations (Zsh, Oh-My-Zsh)
- `databases`    Databases (PostgreSQL, MongoDB, Redis)
- `configs`      Configuration files (.gitconfig, .vimrc)
- `deps`         System dependencies and libraries

### Examples

```bash
# Install everything with default settings
./dev-setup.sh

# Install specific components
./dev-setup.sh -i languages -i tools

# Skip certain components
./dev-setup.sh -s databases -s shells

# Dry run to see what would be installed
./dev-setup.sh -d

# Install with custom config file
./dev-setup.sh -c ~/my-dev-setup.conf

# Verbose installation of specific components
./dev-setup.sh -v -i languages -i tools
```

## Configuration File

The configuration file (`~/.dev-setup.conf`) can contain custom settings:

```bash
# Custom Git configuration
GIT_USER_NAME="Your Name"
GIT_USER_EMAIL="your.email@example.com"

# Node.js version
NODE_VERSION="16.x"

# Python packages to install
PYTHON_PACKAGES=(
    "pytest"
    "black"
    "flake8"
)

# VSCode extensions to install
VSCODE_EXTENSIONS=(
    "ms-python.python"
    "dbaeumer.vscode-eslint"
)
```

## Installed Components

### Programming Languages
- Python 3 with pip, pipenv, virtualenv
- Node.js (LTS) with npm and yarn
- Go

### Development Tools
- Git with basic configuration
- Docker with user permissions
- Visual Studio Code

### Shell Setup
- Zsh
- Oh My Zsh
- Custom shell configuration

### Databases
- PostgreSQL
- MongoDB
- Redis

### Configuration Files
- Git global configuration
- Vim configuration
- SSH configuration

### System Dependencies
- build-essential
- curl
- wget
- vim
- htop
- tmux
- tree
- jq
- unzip

## Logs

- All operations are logged to `~/.dev-setup-YYYYMMDD.log`
- Logs include timestamps and operation details
- Each installation step is documented

## Dependencies

### Required
- Bash 4.0+
- sudo privileges
- Internet connection
- Standard Unix utilities

## Notes

- Use dry-run mode (-d) first to preview changes
- Some installations may require system restart
- Docker installation adds current user to docker group
- Database services are enabled and started automatically
- Custom configurations can be added via config file
- Some components may not be available on all distributions
- Log files are created in user's home directory
