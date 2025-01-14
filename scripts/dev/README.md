# Development Tools

A collection of advanced development workflow automation scripts.

## Scripts Overview

### Project Scaffolding Generator (`project-scaffold.sh`)

Creates a new project with a standardized structure and configuration.

**Features:**
- Multiple project templates (Python, Node.js, Go, Rust)
- Git initialization
- Package manager setup
- Docker configuration
- CI/CD setup
- Testing framework
- Documentation templates

**Usage:**
```bash
./project-scaffold.sh [OPTIONS] PROJECT_NAME

Options:
  -t, --type TYPE      Project type (python|node|go|rust)
  -o, --output DIR     Output directory
  --template-dir DIR   Custom template directory
  --no-git            Don't initialize git repository
  --no-pkg-mgr        Don't initialize package manager
  -d, --docker        Add Docker configuration
  -c, --ci            Add CI/CD configuration
  --no-tests          Don't add testing setup
  --no-docs           Don't add documentation
  -i, --interactive   Interactive mode
```

### Development Environment Setup (`dev-env-setup.sh`)

Automates the setup of development environments.

**Features:**
- Virtual environment creation
- Dependency installation
- Development tools setup
- IDE configuration
- Docker environment setup
- Linters and formatters
- Debugger configuration

**Usage:**
```bash
./dev-env-setup.sh [OPTIONS] PROJECT_DIR

Options:
  -t, --type TYPE      Environment type (python|node|go|rust)
  --no-deps           Don't install dependencies
  --no-tools          Don't setup development tools
  --no-linters        Don't setup linters
  --no-formatters     Don't setup formatters
  --no-debugger       Don't setup debugger
  -i, --ide TYPE      Setup IDE (vscode|intellij|sublime)
  --no-venv           Don't create virtual environment
  -d, --docker        Setup Docker environment
```

### Code Format Checker (`code-format.sh`)

Advanced code formatting and style checking tool.

**Features:**
- Multiple language support
- Parallel processing
- Custom style guides
- Auto-fixing capability
- Detailed reports
- Exclude patterns
- Integration with popular formatters

**Usage:**
```bash
./code-format.sh [OPTIONS] TARGET_DIR

Options:
  -l, --language LANG  Language to format (python|js|go|rust)
  -c, --check         Check only, don't fix issues
  --no-fix            Don't fix issues automatically
  -e, --exclude PAT   Exclude pattern
  --config FILE       Custom configuration file
  -r, --report FILE   Generate report file
  -v, --verbose       Verbose output
  --no-parallel       Disable parallel processing
```

### Build and Deployment Automator (`deploy.sh`)

Comprehensive build and deployment automation tool.

**Features:**
- Multiple deployment environments
- Different build types (Docker, binary, package)
- Backup and rollback
- Health checks
- Notifications
- Dry-run mode
- SSH key authentication
- Docker registry support
- Secrets management

**Usage:**
```bash
./deploy.sh [OPTIONS] PROJECT_DIR

Options:
  -e, --env ENV        Target environment (dev|staging|prod)
  -t, --type TYPE      Build type (docker|binary|package)
  -h, --host HOST      Target host
  -p, --path PATH      Target path
  -c, --config FILE    Configuration file
  --no-backup         Don't create backup
  --no-rollback       Disable rollback
  --no-health         Skip health check
  --dry-run           Simulation mode
  -v, --verbose       Verbose output
  -u, --user USER     Deploy user
  -k, --key FILE      SSH key file
  -r, --registry URL  Docker registry URL
  --version VER       Version to deploy
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/bash-toolkit.git
```

2. Make scripts executable:
```bash
chmod +x scripts/dev/*.sh
```

3. Add to your PATH (optional):
```bash
export PATH="$PATH:/path/to/bash-toolkit/scripts/dev"
```

## Configuration

Each script can be configured through:
- Command-line arguments
- Configuration files
- Environment variables

Example configuration file:
```bash
# config.sh
PROJECT_NAME="my-app"
DOCKER_REGISTRY="registry.example.com"
DEPLOY_USER="deployer"
SLACK_WEBHOOK_URL="https://hooks.slack.com/..."
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
