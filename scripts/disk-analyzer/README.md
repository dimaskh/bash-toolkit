# Disk Analyzer Script

A comprehensive disk space analyzer and cleanup utility that helps identify large files and directories, and optionally cleans up temporary files.

## Features

- Analyzes disk space usage by directory and file type
- Identifies the largest files and directories
- Performs cleanup of temporary files and package manager caches
- Detailed logging of all operations
- Cross-platform compatibility (Linux/MacOS)
- Configurable file size thresholds
- Optional cleanup mode for temporary files
- Package manager cache cleanup (apt, yum, dnf)

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x disk-analyzer.sh
```

2. Optionally, add to your PATH for system-wide access.

## Usage

```bash
./disk-analyzer.sh [OPTIONS]
```

### Options

- `-d, --directory DIR`    Analyze specific directory (default: current directory)
- `-s, --size SIZE`       Minimum file size to report (default: 100M)
- `-c, --cleanup`         Perform cleanup of temporary files
- `-h, --help`           Show this help message

### Examples

```bash
# Analyze current directory
./disk-analyzer.sh

# Analyze specific directory with custom file size threshold
./disk-analyzer.sh -d /home/user/projects -s 500M

# Analyze and perform cleanup
./disk-analyzer.sh -d /var -c
```

## Output

The script provides detailed information about:
1. Top 10 largest directories
2. Files larger than the specified size threshold
3. Disk usage categorized by file type
4. Cleanup operations (if enabled)

## Logs

- All operations are logged to a dated log file in `/tmp/disk-analyzer-YYYYMMDD.log`
- The log includes timestamps and detailed operation information

## Dependencies

- Standard Unix utilities (du, find, sort)
- Package managers (apt-get, yum, or dnf) for cache cleanup

## Notes

- The cleanup operation requires sudo privileges for package manager cache cleanup
- Be cautious when using cleanup mode in production environments
- The script is designed to be non-destructive by default
