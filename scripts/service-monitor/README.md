# Service Monitor Script

An advanced service monitoring and management script that supports multiple init systems and provides real-time monitoring capabilities.

## Features

- Support for multiple init systems:
  - systemd
  - SysVinit
  - Upstart
- Real-time service monitoring
- Email notifications on status changes
- Service management capabilities (start/stop/restart)
- Bulk service monitoring
- Service list from file
- Configurable monitoring interval
- Detailed logging
- Color-coded output
- Support for all services listing

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x service-monitor.sh
```

2. Optional dependencies for notifications:
```bash
# For email notifications
sudo apt-get install mailutils  # For Debian/Ubuntu
sudo yum install mailx         # For RHEL/CentOS
```

## Usage

```bash
./service-monitor.sh [OPTIONS] [SERVICE...]
```

### Options

- `-w, --watch`           Monitor services continuously
- `-i, --interval SEC`    Watch interval in seconds (default: 5)
- `-n, --notify EMAIL`    Send email notifications on service status changes
- `-f, --file FILE`       Read service names from file
- `-a, --all`            Show all services
- `-r, --restart SERVICE` Restart specified service
- `-s, --start SERVICE`   Start specified service
- `-p, --stop SERVICE`    Stop specified service
- `-h, --help`           Show this help message

### Examples

```bash
# Monitor specific services continuously
./service-monitor.sh -w nginx mysql

# Monitor with email notifications
./service-monitor.sh -w -n admin@example.com nginx

# Monitor services listed in a file
./service-monitor.sh -w -f services.txt

# Show status of all services
./service-monitor.sh -a

# Restart a specific service
./service-monitor.sh -r nginx

# Monitor with custom interval
./service-monitor.sh -w -i 10 nginx
```

## Service File Format

When using the `-f` option, the service file should contain one service name per line:
```
nginx
mysql
apache2
postgresql
# Lines starting with # are ignored
```

## Operation Details

The script performs the following operations:
1. Detects the init system in use
2. Validates service names
3. Monitors service status at specified intervals
4. Sends notifications on status changes (if enabled)
5. Logs all operations

## Logs

- All operations are logged to `/var/log/service-monitor-YYYYMMDD.log`
- Logs include timestamps and operation details
- Each status change is documented

## Dependencies

### Required
- Standard Unix utilities
- sudo privileges
- Compatible init system (systemd, SysVinit, or Upstart)

### Optional
- mailutils/mailx (for email notifications)

## Notes

- Requires sudo privileges for service control operations
- Email notifications require a configured MTA (Mail Transfer Agent)
- The script automatically detects and adapts to the system's init system
- Color output works best in terminals supporting ANSI colors
- Service names are case-sensitive
