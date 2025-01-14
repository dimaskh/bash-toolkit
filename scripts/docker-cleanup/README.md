# Docker Cleanup Script

An advanced Docker resource management and cleanup script that helps maintain a clean Docker environment by removing unused containers, images, volumes, and networks.

## Features

- Comprehensive cleanup options:
  - Stopped containers
  - Unused images
  - Dangling volumes
  - Unused networks
- Advanced filtering:
  - Age-based filtering
  - Size-based filtering
  - Pattern matching (include/exclude)
- Safety features:
  - Dry-run mode
  - Confirmation prompts
  - Pattern exclusions
- Detailed logging
- Resource size analysis
- Force mode for automation
- Color-coded output

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x docker-cleanup.sh
```

2. Ensure you have Docker installed and running.

## Usage

```bash
./docker-cleanup.sh [OPTIONS]
```

### Options

- `-a, --all`               Remove all unused resources
- `-c, --containers`        Remove stopped containers
- `-i, --images`           Remove dangling images
- `-v, --volumes`          Remove unused volumes
- `-n, --networks`         Remove unused networks
- `-o, --older DAYS`       Remove items older than DAYS (default: 7)
- `-s, --size SIZE`        Remove images larger than SIZE (default: 10GB)
- `-e, --exclude PATTERN`  Exclude items matching pattern
- `-p, --pattern PATTERN`  Include only items matching pattern
- `-f, --force`            Don't ask for confirmation
- `-d, --dry-run`          Show what would be removed
- `-h, --help`             Show this help message

### Examples

```bash
# Remove all unused resources
./docker-cleanup.sh --all

# Remove containers and images older than 30 days
./docker-cleanup.sh -c -i --older 30

# Remove large images (>20GB) with dry-run
./docker-cleanup.sh --images --size 20GB --dry-run

# Clean everything except specific patterns
./docker-cleanup.sh --all --exclude "production-*" --exclude "backup-*"

# Force cleanup of specific resource types
./docker-cleanup.sh --containers --volumes --force

# Remove only specific patterns
./docker-cleanup.sh --all --pattern "test-*" --pattern "dev-*"
```

## Operation Details

The script performs the following checks and operations:
1. Verifies Docker daemon is running
2. Identifies resources matching specified criteria
3. Applies age and size filters
4. Checks include/exclude patterns
5. Performs cleanup operations
6. Logs all actions

## Resource Types

### Containers
- Removes stopped containers
- Age-based filtering
- Pattern matching for container names

### Images
- Removes unused images
- Size-based filtering
- Age-based filtering
- Pattern matching for image tags

### Volumes
- Removes unused volumes
- Pattern matching for volume names

### Networks
- Removes unused networks
- Pattern matching for network names

## Logs

- All operations are logged to `/var/log/docker-cleanup-YYYYMMDD.log`
- Logs include timestamps and operation details
- Each cleanup action is documented

## Dependencies

### Required
- Docker
- Bash 4.0+
- Standard Unix utilities

## Notes

- Use dry-run mode (-d) first to preview changes
- Consider using exclude patterns for critical resources
- Size thresholds accept KB, MB, GB, TB units
- The script requires appropriate Docker permissions
- Force mode skips all confirmation prompts
- Log files require write permissions
- Color output works best in terminals supporting ANSI colors
