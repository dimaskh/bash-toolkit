# System Update Script

A universal system update script that handles package updates across various Linux distributions.

## Features

- Supports multiple Linux distributions:
  - Ubuntu/Debian
  - Fedora
  - CentOS/RHEL
  - Arch Linux
- Automatic distribution detection
- Security-only updates option
- System snapshot creation before updates (using Timeshift or Snapper)
- Dry-run mode to preview updates
- Automatic cleanup after updates
- Detailed logging of all operations
- Non-interactive mode available
- Package cache cleanup

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x system-update.sh
```

2. Optionally, add to your PATH for system-wide access.

## Usage

```bash
./system-update.sh [OPTIONS]
```

### Options

- `-y, --yes`             Automatic yes to prompts
- `-s, --security-only`   Only install security updates
- `-b, --backup`          Create system snapshot before updating
- `-n, --dry-run`         Show what would be updated without installing
- `-h, --help`            Show this help message

### Examples

```bash
# Basic system update with prompts
./system-update.sh

# Non-interactive update with backup
./system-update.sh -y -b

# Security updates only in dry-run mode
./system-update.sh -s -n

# Full automatic update with all options
./system-update.sh -y -b -s
```

## Operation Details

The script performs the following operations in sequence:
1. Detects the Linux distribution
2. Creates a system snapshot (if requested)
3. Updates package lists
4. Performs system upgrade
5. Cleans up package cache
6. Logs all operations

## Logs

- All operations are logged to `/var/log/system-update-YYYYMMDD.log`
- Logs include timestamps and operation details
- Each operation is clearly documented for audit purposes

## Dependencies

### Required
- Standard Unix utilities
- Distribution-specific package managers (apt, dnf, yum, or pacman)
- sudo privileges

### Optional
- Timeshift or Snapper for system snapshots

## Notes

- Requires sudo privileges for most operations
- Use dry-run mode first to preview changes
- Creating system snapshots requires additional disk space
- Security-only updates might not be available on all distributions
- The script automatically detects and adapts to the host distribution
