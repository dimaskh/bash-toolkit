# Log Manager Script

An advanced log rotation and cleanup utility that helps manage system and application logs efficiently.

## Features

- Automatic log rotation based on file size
- Multiple compression options (gzip, bzip2, or none)
- Configurable retention period
- Dry-run mode for safe testing
- Detailed logging of operations
- Preserves file permissions and ownership
- Safe rotation that doesn't interrupt running applications
- Pattern-based log file matching
- Configurable size thresholds
- Automatic cleanup of old rotated logs

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x log-manager.sh
```

2. Optionally, add to your PATH for system-wide access.

## Usage

```bash
./log-manager.sh [OPTIONS]
```

### Options

- `-d, --directory DIR`     Log directory to process (required)
- `-p, --pattern PATTERN`   Log file pattern (e.g., '*.log') (required)
- `-s, --max-size SIZE`     Maximum size for log files (default: 100M)
- `-r, --retention DAYS`    Days to keep logs (default: 30)
- `-c, --compress TYPE`     Compression type (gzip|bzip2|none) (default: gzip)
- `-n, --dry-run`          Show what would be done without doing it
- `-h, --help`             Show this help message

### Examples

```bash
# Rotate and compress nginx logs
./log-manager.sh -d /var/log/nginx -p "*.log" -s 50M -r 14

# Dry run to see what would happen
./log-manager.sh -d /var/log/myapp -p "app.log" -n

# Use bzip2 compression and keep logs for 60 days
./log-manager.sh -d /var/log -p "syslog" -c bzip2 -r 60
```

## Operation Details

The script performs the following operations:
1. Checks log files in the specified directory matching the pattern
2. Rotates files that exceed the size threshold
3. Applies the selected compression method
4. Removes old rotated logs beyond the retention period
5. Maintains detailed operation logs

## Logs

- All operations are logged to `/var/log/log-manager.log`
- Logs include timestamps and operation details
- Each operation is clearly documented for audit purposes

## Dependencies

- Standard Unix utilities (find, stat, gzip/bzip2)
- Sufficient permissions to access and modify log files
- Write access to the log directory

## Notes

- May require sudo privileges depending on log file permissions
- Use dry-run mode first to verify intended operations
- Designed to be safe for use with active applications
- Maintains original file ownership and permissions
- Creates compressed archives with timestamps for easy tracking
