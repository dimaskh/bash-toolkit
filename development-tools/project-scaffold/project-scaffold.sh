#!/bin/bash

# project-scaffold.sh
# Advanced project scaffolding generator with multiple templates and configurations
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
PROJECT_NAME=""
PROJECT_TYPE="python"  # python, node, go, rust, etc.
TEMPLATE_DIR="$HOME/.project-templates"
OUTPUT_DIR=""
GIT_INIT=true
PACKAGE_MANAGER=true
DOCKER=false
CI_CD=false
TESTING=true
DOCUMENTATION=true
LOG_FILE=""
INTERACTIVE=false
VARIABLES=()
FORCE=false

# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS] PROJECT_NAME"
    echo
    echo "Options:"
    echo "  -t, --type TYPE      Project type (python|node|go|rust)"
    echo "  -o, --output DIR     Output directory"
    echo "  --template-dir DIR   Custom template directory"
    echo "  --no-git            Don't initialize git repository"
    echo "  --no-pkg-mgr        Don't initialize package manager"
    echo "  -d, --docker        Add Docker configuration"
    echo "  -c, --ci            Add CI/CD configuration"
    echo "  --no-tests          Don't add testing setup"
    echo "  --no-docs           Don't add documentation"
    echo "  -i, --interactive   Interactive mode"
    echo "  -v, --var KEY=VALUE Add template variable"
    echo "  -f, --force         Force overwrite existing files"
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

# Function to validate project name
validate_project_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        log_message "ERROR" "Invalid project name. Use only letters, numbers, hyphens, and underscores"
        exit 1
    fi
}

# Function to create directory structure
create_directory_structure() {
    local dir="$1"
    local type="$2"
    
    case "$type" in
        python)
            mkdir -p "$dir"/{src,tests,docs,scripts}
            touch "$dir/src/__init__.py"
            touch "$dir/tests/__init__.py"
            ;;
        node)
            mkdir -p "$dir"/{src,test,docs,scripts}
            mkdir -p "$dir/src/"{components,utils,styles}
            ;;
        go)
            mkdir -p "$dir"/{cmd,internal,pkg,docs,scripts}
            mkdir -p "$dir/internal/"{app,pkg}
            ;;
        rust)
            mkdir -p "$dir"/{src,tests,docs,scripts}
            mkdir -p "$dir/src/"{bin,lib}
            ;;
    esac
    
    mkdir -p "$dir"/{.github/workflows,config}
}

# Function to generate package manager files
generate_package_files() {
    local dir="$1"
    local type="$2"
    
    case "$type" in
        python)
            cat > "$dir/setup.py" << EOF
from setuptools import setup, find_packages

setup(
    name='${PROJECT_NAME}',
    version='0.1.0',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    install_requires=[],
    extras_require={
        'dev': ['pytest', 'pylint', 'black', 'mypy'],
    },
)
EOF
            cat > "$dir/requirements.txt" << EOF
# Add your project dependencies here
EOF
            ;;
        
        node)
            cat > "$dir/package.json" << EOF
{
  "name": "${PROJECT_NAME}",
  "version": "0.1.0",
  "description": "",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "jest",
    "lint": "eslint .",
    "format": "prettier --write ."
  },
  "dependencies": {},
  "devDependencies": {
    "jest": "^29.0.0",
    "eslint": "^8.0.0",
    "prettier": "^3.0.0"
  }
}
EOF
            ;;
        
        go)
            cat > "$dir/go.mod" << EOF
module ${PROJECT_NAME}

go 1.21
EOF
            ;;
        
        rust)
            cat > "$dir/Cargo.toml" << EOF
[package]
name = "${PROJECT_NAME}"
version = "0.1.0"
edition = "2021"

[dependencies]

[dev-dependencies]
EOF
            ;;
    esac
}

# Function to generate Docker configuration
generate_docker_config() {
    local dir="$1"
    local type="$2"
    
    cat > "$dir/Dockerfile" << EOF
# Use appropriate base image for ${type}
FROM ${type}:latest

# Set working directory
WORKDIR /app

# Copy dependency files
COPY . .

# Install dependencies
RUN ${type}-dependency-install-command

# Build application
RUN ${type}-build-command

# Start application
CMD ["${type}-start-command"]
EOF
    
    cat > "$dir/docker-compose.yml" << EOF
version: '3.8'
services:
  app:
    build: .
    ports:
      - "8080:8080"
    volumes:
      - .:/app
    environment:
      - NODE_ENV=development
EOF
}

# Function to generate CI/CD configuration
generate_ci_config() {
    local dir="$1"
    local type="$2"
    
    cat > "$dir/.github/workflows/ci.yml" << EOF
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up ${type}
      uses: actions/setup-${type}@v3
    - name: Install dependencies
      run: ${type}-install-command
    - name: Run tests
      run: ${type}-test-command
    - name: Run linting
      run: ${type}-lint-command
EOF
}

# Function to generate testing configuration
generate_test_config() {
    local dir="$1"
    local type="$2"
    
    case "$type" in
        python)
            cat > "$dir/tests/conftest.py" << EOF
import pytest

# Add your pytest fixtures here
EOF
            cat > "$dir/tests/test_sample.py" << EOF
def test_sample():
    assert True
EOF
            ;;
        
        node)
            cat > "$dir/test/sample.test.js" << EOF
describe('Sample Test', () => {
    it('should pass', () => {
        expect(true).toBe(true);
    });
});
EOF
            ;;
        
        go)
            cat > "$dir/internal/app/app_test.go" << EOF
package app

import "testing"

func TestSample(t *testing.T) {
    // Add your tests here
}
EOF
            ;;
        
        rust)
            cat > "$dir/tests/sample_test.rs" << EOF
#[cfg(test)]
mod tests {
    #[test]
    fn test_sample() {
        assert!(true);
    }
}
EOF
            ;;
    esac
}

# Function to generate documentation
generate_documentation() {
    local dir="$1"
    local type="$2"
    
    cat > "$dir/README.md" << EOF
# ${PROJECT_NAME}

## Description

Add your project description here.

## Installation

\`\`\`bash
# Add installation instructions
\`\`\`

## Usage

\`\`\`bash
# Add usage examples
\`\`\`

## Development

### Prerequisites

- List prerequisites here

### Setup

\`\`\`bash
# Add setup instructions
\`\`\`

### Testing

\`\`\`bash
# Add testing instructions
\`\`\`

### Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
EOF
    
    cat > "$dir/docs/index.md" << EOF
# ${PROJECT_NAME} Documentation

Welcome to the ${PROJECT_NAME} documentation.

## Table of Contents

1. [Getting Started](getting-started.md)
2. [Configuration](configuration.md)
3. [API Reference](api-reference.md)
4. [Contributing](contributing.md)
EOF
}

# Function to initialize git repository
init_git_repo() {
    local dir="$1"
    
    git -C "$dir" init
    cat > "$dir/.gitignore" << EOF
# Python
__pycache__/
*.py[cod]
*.so
.Python
env/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Node
node_modules/
npm-debug.log
yarn-debug.log
yarn-error.log
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Go
/vendor/
/dist/
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out

# Rust
/target/
**/*.rs.bk
Cargo.lock

# IDEs
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
    
    git -C "$dir" add .
    git -C "$dir" commit -m "Initial commit"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --template-dir)
            TEMPLATE_DIR="$2"
            shift 2
            ;;
        --no-git)
            GIT_INIT=false
            shift
            ;;
        --no-pkg-mgr)
            PACKAGE_MANAGER=false
            shift
            ;;
        -d|--docker)
            DOCKER=true
            shift
            ;;
        -c|--ci)
            CI_CD=true
            shift
            ;;
        --no-tests)
            TESTING=false
            shift
            ;;
        --no-docs)
            DOCUMENTATION=false
            shift
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -v|--var)
            VARIABLES+=("$2")
            shift 2
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
            if [ -z "$PROJECT_NAME" ]; then
                PROJECT_NAME="$1"
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
    PROJECT_NAME=$(prompt_user "Project name" "${PROJECT_NAME}")
    PROJECT_TYPE=$(prompt_user "Project type (python|node|go|rust)" "${PROJECT_TYPE}")
    GIT_INIT=$(prompt_user "Initialize git repository? (true|false)" "${GIT_INIT}")
    PACKAGE_MANAGER=$(prompt_user "Initialize package manager? (true|false)" "${PACKAGE_MANAGER}")
    DOCKER=$(prompt_user "Add Docker configuration? (true|false)" "${DOCKER}")
    CI_CD=$(prompt_user "Add CI/CD configuration? (true|false)" "${CI_CD}")
    TESTING=$(prompt_user "Add testing setup? (true|false)" "${TESTING}")
    DOCUMENTATION=$(prompt_user "Add documentation? (true|false)" "${DOCUMENTATION}")
fi

# Validate arguments
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Project name is required"
    print_usage
    exit 1
fi

validate_project_name "$PROJECT_NAME"

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$PWD/$PROJECT_NAME"
fi

# Check if project directory exists
if [ -d "$OUTPUT_DIR" ] && [ "$FORCE" = false ]; then
    echo "Error: Directory already exists: $OUTPUT_DIR"
    exit 1
fi

# Initialize log file
if [ -n "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Create project
log_message "INFO" "Creating project: $PROJECT_NAME"
log_message "INFO" "Type: $PROJECT_TYPE"
log_message "INFO" "Output directory: $OUTPUT_DIR"

# Create directory structure
create_directory_structure "$OUTPUT_DIR" "$PROJECT_TYPE"

# Generate package manager files
if [ "$PACKAGE_MANAGER" = true ]; then
    log_message "INFO" "Generating package manager files..."
    generate_package_files "$OUTPUT_DIR" "$PROJECT_TYPE"
fi

# Generate Docker configuration
if [ "$DOCKER" = true ]; then
    log_message "INFO" "Generating Docker configuration..."
    generate_docker_config "$OUTPUT_DIR" "$PROJECT_TYPE"
fi

# Generate CI/CD configuration
if [ "$CI_CD" = true ]; then
    log_message "INFO" "Generating CI/CD configuration..."
    generate_ci_config "$OUTPUT_DIR" "$PROJECT_TYPE"
fi

# Generate testing configuration
if [ "$TESTING" = true ]; then
    log_message "INFO" "Generating testing configuration..."
    generate_test_config "$OUTPUT_DIR" "$PROJECT_TYPE"
fi

# Generate documentation
if [ "$DOCUMENTATION" = true ]; then
    log_message "INFO" "Generating documentation..."
    generate_documentation "$OUTPUT_DIR" "$PROJECT_TYPE"
fi

# Initialize git repository
if [ "$GIT_INIT" = true ]; then
    log_message "INFO" "Initializing git repository..."
    init_git_repo "$OUTPUT_DIR"
fi

log_message "INFO" "Project creation completed successfully."
echo
echo "Next steps:"
echo "1. cd $OUTPUT_DIR"
echo "2. Review and update configuration files"
echo "3. Install dependencies"
echo "4. Start developing!"
