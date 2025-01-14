# Project Dependency Checker Script

An advanced script for analyzing and managing project dependencies across multiple programming languages and package managers.

## Features

- Multi-language support:
  - Node.js (npm)
  - Python (pip, pipenv)
  - Go (modules)
  - Java (Maven, Gradle)
  - Ruby (Bundler)
  - PHP (Composer)
- Dependency analysis:
  - Installed packages
  - Available updates
  - Security vulnerabilities
- Advanced features:
  - Recursive project scanning
  - Multiple output formats
  - Pattern exclusion
  - Depth control
  - Interactive mode
- Detailed logging
- Color-coded output

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x dep-checker.sh
```

2. Install language-specific tools (as needed):
```bash
# For Node.js projects
npm install -g npm-check-updates

# For Python projects
pip install safety

# For PHP projects
composer global require security-checker
```

## Usage

```bash
./dep-checker.sh [OPTIONS] [PROJECT_DIR]
```

### Options

- `-u, --updates`          Check for available updates
- `-s, --security`         Perform security vulnerability check
- `-i, --interactive`      Interactive mode for updates
- `-f, --format FORMAT`    Output format (text|json|csv)
- `-e, --exclude PATTERN`  Exclude paths matching pattern
- `-m, --max-depth N`      Maximum search depth (default: 3)
- `-v, --verbose`          Verbose output
- `-h, --help`             Show this help message

### Examples

```bash
# Check dependencies in current directory
./dep-checker.sh

# Check for updates in specific project
./dep-checker.sh -u /path/to/project

# Security check with JSON output
./dep-checker.sh -s -f json

# Recursive check excluding test directories
./dep-checker.sh -e "test" -e "spec"

# Interactive update check with maximum depth
./dep-checker.sh -u -i -m 2

# Full check with all features
./dep-checker.sh -u -s -i -v
```

## Supported Project Types

### Node.js
- Detects `package.json`
- Lists installed packages
- Checks for updates using npm
- Performs security audit

### Python
- Detects `requirements.txt`, `setup.py`, `Pipfile`
- Supports pip and pipenv
- Lists installed packages
- Checks for updates
- Performs security check using safety

### Go
- Detects `go.mod`
- Lists all modules
- Checks for available updates

### Java
- Detects `pom.xml` and `build.gradle`
- Supports Maven and Gradle
- Lists dependencies
- Checks for updates

### Ruby
- Detects `Gemfile`
- Lists installed gems
- Checks for outdated packages

### PHP
- Detects `composer.json`
- Lists installed packages
- Checks for updates
- Performs security audit

## Output Formats

### Text (default)
- Human-readable format
- Color-coded sections
- Hierarchical display

### JSON
- Machine-readable format
- Suitable for parsing
- Contains all check details

### CSV
- Spreadsheet-compatible
- Simple to import
- Basic information only

## Logs

- All operations are logged to `~/.dep-checker-YYYYMMDD.log`
- Logs include timestamps and operation details
- Each check is documented with results

## Dependencies

### Required
- Bash 4.0+
- jq (for JSON output)
- Language-specific package managers

### Optional
- npm-check-updates (for Node.js)
- safety (for Python)
- composer security-checker (for PHP)

## Notes

- Some checks require appropriate language tools to be installed
- Security checks may require internet connection
- Interactive mode works best in terminal environment
- Exclude patterns use bash pattern matching
- Maximum depth applies to directory traversal
- Color output works best in terminals supporting ANSI colors
