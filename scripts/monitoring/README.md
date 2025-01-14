# Performance Monitoring Scripts

A collection of comprehensive system performance monitoring tools.

## Scripts

### 1. CPU Monitor (`cpu-monitor.sh`)

Advanced CPU usage monitoring and analysis tool.

#### Features

- Real-time CPU usage monitoring
- Per-core statistics
- Process CPU usage tracking
- Temperature monitoring
- Frequency monitoring
- Multiple output formats
- Email alerts
- Threshold monitoring
- Data export (CSV/JSON)
- Detailed logging

#### Usage

```bash
./cpu-monitor.sh [OPTIONS]
```

### 2. Memory Monitor (`memory-monitor.sh`)

Comprehensive memory usage monitoring tool.

#### Features

- Real-time memory monitoring
- Swap usage tracking
- Process memory analysis
- Multiple output formats
- Email alerts
- Threshold monitoring
- Data export (CSV/JSON)
- Detailed logging

#### Usage

```bash
./memory-monitor.sh [OPTIONS]
```

### 3. Process Monitor (`process-monitor.sh`)

Process resource usage analyzer and monitor.

#### Features

- Process resource tracking
- Thread monitoring
- System call tracing
- File operations monitoring
- Multiple output formats
- Email alerts
- Threshold monitoring
- Data export (CSV/JSON)
- Detailed logging

#### Usage

```bash
./process-monitor.sh [OPTIONS] [PROCESS_PATTERN]
```

### 4. I/O Monitor (`io-monitor.sh`)

I/O operations monitoring and analysis tool.

#### Features

- Disk I/O monitoring
- IOPS tracking
- Bandwidth monitoring
- Process I/O analysis
- Multiple output formats
- Email alerts
- Threshold monitoring
- Data export (CSV/JSON)
- Detailed logging

#### Usage

```bash
./io-monitor.sh [OPTIONS] [DEVICE]
```

## Installation

1. Ensure all scripts have executable permissions:
```bash
chmod +x *.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install sysstat iotop bc jq mailutils

# For RHEL/CentOS
sudo yum install sysstat iotop bc jq mailx
```

## Common Features

All scripts include:

- Real-time monitoring
- Multiple output formats (text, JSON, CSV)
- Email notifications
- Threshold alerts
- Data export
- Daemon mode
- Detailed logging
- Process analysis

## Output Formats

- Text: Human-readable output
- JSON: Structured data format
- CSV: Spreadsheet-compatible format

## Monitoring Options

- Sampling interval
- Sample count
- Custom thresholds
- Email notifications
- Alert intervals
- Process filtering
- Data export

## Security

- No sensitive data in logs
- Safe process monitoring
- Configurable permissions

## Notes

- Some scripts require root privileges
- Email alerts require configured mail system
- Monitor resource usage
- Adjust thresholds as needed
- Regular log rotation recommended
