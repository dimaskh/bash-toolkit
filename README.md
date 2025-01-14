# Useful Bash Scripts Collection

A comprehensive collection of useful bash scripts designed to automate common system administration tasks and enhance productivity on Unix-based systems (MacOS and Linux). Each script is carefully crafted to be cross-platform compatible and includes detailed documentation for ease of use.

## Installation

1. Clone this repository:

```bash
git clone https://github.com/dimaskh/bash-toolkit.git
```

2. Navigate to the repository directory:

```bash
cd bash-toolkit
```

3. Make the scripts executable:

```bash
find . -name "*.sh" -type f -exec chmod +x {} \;
```

4. (Optional) Add scripts to your PATH by adding this line to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$PATH:/path/to/bash-toolkit/scripts"
```

## Project Structure

```
bash-toolkit/
├── README.md
├── scripts/
    ├── disk-analyzer/
    │   ├── disk-analyzer.sh
    │   └── README.md
    ├── log-manager/
    │   ├── log-manager.sh
    │   └── README.md
```

## Available Scripts

### System Tools

#### [Disk Analyzer](scripts/disk-analyzer/README.md)
A comprehensive disk space analyzer and cleanup utility that helps identify large files and directories, and optionally cleans up temporary files.

#### [Log Manager](scripts/log-manager/README.md)
An advanced log rotation and cleanup utility that helps manage system and application logs efficiently.

## Upcoming Scripts

### System Maintenance
- System update automation
- Service status monitor

### Development Tools
- Git repository bulk operations
- Docker container cleanup
- Development environment setup
- Project dependency checker

### Network Tools
- Network connectivity tester
- Port scanner
- DNS lookup utilities
- SSL certificate monitor

### Security Scripts
- File permission auditor
- SSH key management
- Failed login attempts monitor
- Security updates checker

### Backup and Recovery
- Incremental backup script
- Database backup automation
- Config files backup
- Restore point creator

### Performance Monitoring
- CPU usage monitor
- Memory usage tracker
- Process resource usage analyzer
- I/O operations monitor

### File Management
- Duplicate file finder
- Large file locator
- File organization by type
- Bulk file renamer

### Development Workflow
- Project scaffolding generator
- Local development environment setup
- Code formatting checker
- Build and deployment automator

## Usage

Each script has its own README.md file in its directory with specific usage instructions.

## Contributing

Feel free to submit issues and pull requests.

## License

MIT License
