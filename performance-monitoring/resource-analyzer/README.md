# System Resource Analyzer

A comprehensive suite of tools for monitoring and analyzing system resources.

## Components

### CPU Monitor
Tracks CPU usage, load averages, and process CPU consumption.

### Memory Monitor
Monitors memory usage, swap activity, and memory-intensive processes.

### Process Monitor
Analyzes process resource usage, threads, and system calls.

### I/O Monitor
Tracks disk I/O operations, bandwidth usage, and process I/O activity.

## Features

- Real-time monitoring
- Historical data collection
- Configurable alerts
- Multiple output formats
- Email notifications
- Detailed logging
- Export capabilities
- Threshold-based alerts
- Process tracking
- Resource usage analysis

## Usage

### CPU Monitor
```bash
./cpu-monitor.sh [OPTIONS]

Options:
  -i, --interval SEC    Sampling interval
  -t, --threshold PCT   Alert threshold
  -f, --format FMT     Output format
  -n, --notify         Enable notifications
  --log FILE          Log file path
```

### Memory Monitor
```bash
./memory-monitor.sh [OPTIONS]

Options:
  -i, --interval SEC    Sampling interval
  -t, --threshold PCT   Alert threshold
  -s, --swap           Monitor swap usage
  -n, --notify         Enable notifications
  --log FILE          Log file path
```

### Process Monitor
```bash
./process-monitor.sh [OPTIONS]

Options:
  -p, --pid PID        Process ID to monitor
  -n, --name NAME      Process name to monitor
  -t, --threads        Monitor threads
  -s, --syscalls      Monitor system calls
  --log FILE          Log file path
```

### I/O Monitor
```bash
./io-monitor.sh [OPTIONS]

Options:
  -d, --device DEV     Device to monitor
  -p, --process PID    Process to monitor
  -i, --interval SEC   Sampling interval
  -b, --bandwidth      Monitor bandwidth
  --log FILE          Log file path
```

## Examples

1. Monitor CPU with 5-second intervals:
```bash
./cpu-monitor.sh -i 5
```

2. Monitor memory with 80% threshold:
```bash
./memory-monitor.sh -t 80
```

3. Monitor specific process:
```bash
./process-monitor.sh -p 1234
```

4. Monitor disk I/O:
```bash
./io-monitor.sh -d /dev/sda
```

## Output Formats

### Text Format
```
CPU Usage: 45%
Memory Usage: 6.2GB/16GB
Swap Usage: 0.5GB/8GB
Disk I/O: Read 25MB/s, Write 10MB/s
```

### JSON Format
```json
{
  "cpu": {
    "usage": 45,
    "load": [1.2, 1.0, 0.8]
  },
  "memory": {
    "used": 6442450944,
    "total": 17179869184
  }
}
```

## Dependencies

- `top`/`htop`
- `vmstat`
- `iostat`
- `strace` (optional)
- `sysstat` package
