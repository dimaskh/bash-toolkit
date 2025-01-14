# Network Connectivity Tester Script

An advanced network diagnostic tool for testing connectivity, monitoring network performance, and troubleshooting network issues.

## Features

- Multiple test modes:
  - Basic connectivity (ping)
  - Full network diagnostics
  - Port availability scanning
  - Traceroute analysis
  - DNS resolution testing
- Advanced features:
  - Continuous monitoring
  - Latency threshold alerts
  - Email notifications
  - Multiple output formats
  - Custom test intervals
- Performance metrics:
  - Response time
  - Packet loss
  - DNS resolution time
  - Port availability
  - Network path analysis
- Detailed logging
- Color-coded output

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x network-tester.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install netcat-openbsd dnsutils traceroute curl jq mailutils

# For RHEL/CentOS
sudo yum install nc bind-utils traceroute curl jq mailx
```

## Usage

```bash
./network-tester.sh [OPTIONS] HOST
```

### Options

- `-p, --port PORT`        Specific port to test
- `-t, --timeout SEC`      Timeout in seconds (default: 5)
- `-i, --interval SEC`     Interval between tests (default: 1)
- `-c, --count NUM`        Number of tests to run (default: 3)
- `-m, --mode MODE`        Test mode (basic|full|port-scan|trace|dns)
- `-f, --format FORMAT`    Output format (text|json|csv)
- `-w, --watch`           Continuous monitoring
- `-T, --threshold MS`     Alert threshold in ms (default: 1000)
- `-e, --email ADDRESS`    Email for alerts
- `-v, --verbose`         Verbose output
- `-h, --help`            Show this help message

### Test Modes

#### Basic Mode
- Simple ping test
- Response time measurement
- Packet loss calculation
```bash
./network-tester.sh example.com
```

#### Full Mode
- Comprehensive network diagnostics
- All available tests
- Detailed results
```bash
./network-tester.sh -m full example.com
```

#### Port Scan Mode
- Common ports availability check
- Service detection
```bash
./network-tester.sh -m port-scan example.com
```

#### Trace Mode
- Network path analysis
- Hop-by-hop latency
```bash
./network-tester.sh -m trace example.com
```

#### DNS Mode
- DNS resolution testing
- Multiple DNS servers
```bash
./network-tester.sh -m dns example.com
```

### Examples

```bash
# Basic connectivity test
./network-tester.sh google.com

# Full diagnostics with continuous monitoring
./network-tester.sh -m full -w google.com

# Port scan with custom timeout
./network-tester.sh -m port-scan -t 10 example.com

# Basic test with email alerts
./network-tester.sh -e admin@example.com -T 500 server.com

# DNS test with JSON output
./network-tester.sh -m dns -f json domain.com

# Continuous monitoring with custom interval
./network-tester.sh -w -i 5 -c 10 service.com
```

## Output Formats

### Text (default)
- Human-readable format
- Color-coded output
- Detailed statistics

### JSON
- Machine-readable format
- Structured data
- Easy parsing

### CSV
- Spreadsheet-compatible
- Time-series data
- Simple format

## Alerts

- Latency threshold alerts
- Connectivity failure alerts
- Email notifications
- Custom thresholds

## Logs

- All operations logged to `~/.network-tester-YYYYMMDD.log`
- Timestamps for all events
- Test results and statistics
- Error messages

## Dependencies

### Required
- ping
- netcat (nc)
- dig (dnsutils)
- traceroute
- curl
- jq (for JSON output)
- mail (for alerts)

## Notes

- Some tests require root privileges
- Email alerts require configured mail system
- Color output works best in ANSI-compatible terminals
- Continuous monitoring can be stopped with Ctrl+C
- DNS tests use Google and Cloudflare servers
- Port scan checks common service ports
- Full diagnostics may take longer to complete
- Log files rotate daily
