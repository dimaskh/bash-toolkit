# Network Tools

A collection of scripts for network diagnostics, monitoring, and troubleshooting.

## Scripts

### 1. Network Connectivity Tester (`network-tester.sh`)

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

---

### 2. Bandwidth Monitor (`bandwidth-monitor.sh`)

Real-time network bandwidth monitoring and analysis tool with advanced visualization and alerting capabilities.

#### Features

- Real-time monitoring:
  - Download/Upload speeds
  - Data transfer rates
  - Interface statistics
- Multiple display units (B, KB, MB, GB)
- Visualization:
  - ASCII graphs
  - Historical data
  - Process-specific usage
- Advanced features:
  - Threshold alerts
  - Email notifications
  - Data logging
  - Multiple output formats
- Process monitoring
- Historical analysis

#### Installation

1. Ensure the script has executable permissions:
```bash
chmod +x bandwidth-monitor.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install bc nethogs iftop

# For RHEL/CentOS
sudo yum install bc nethogs iftop
```

#### Usage

```bash
./bandwidth-monitor.sh [OPTIONS]
```

##### Options

- `-i, --interface IF`     Network interface to monitor
- `-n, --interval SEC`     Update interval in seconds (default: 1)
- `-u, --unit UNIT`        Display unit (B|KB|MB|GB)
- `-f, --format FORMAT`    Output format (text|json|csv)
- `-t, --threshold VAL`    Alert threshold (in specified unit)
- `-e, --email ADDRESS`    Email for alerts
- `-l, --log`             Log data to file
- `-g, --graph`           Show ASCII graph
- `-p, --processes`       Show top bandwidth processes
- `-H, --history`         Show historical data
- `-v, --verbose`         Verbose output
- `-h, --help`            Show this help message

##### Examples

```bash
# Monitor eth0 interface with ASCII graph
./bandwidth-monitor.sh -i eth0 -g

# Monitor with process tracking and MB units
./bandwidth-monitor.sh -i wlan0 -u MB -p

# Monitor with threshold alerts
./bandwidth-monitor.sh -i eth0 -t 100 -e admin@example.com

# Monitor with logging and CSV output
./bandwidth-monitor.sh -i eth0 -l -f csv

# Show historical data with graphs
./bandwidth-monitor.sh -i eth0 -H -g
```

#### Output Formats

##### Text (default)
```
2025-01-14 12:10:15 - RX: 2.45 MB/s | TX: 1.23 MB/s
```

##### JSON
```json
{
  "timestamp": "2025-01-14 12:10:15",
  "rx_speed": 2.45,
  "tx_speed": 1.23,
  "unit": "MB"
}
```

##### CSV
```
2025-01-14 12:10:15,2.45,1.23,MB
```

#### Alerts

- Threshold-based alerts
- Email notifications
- Configurable thresholds
- Custom alert messages

#### Logs

- All data logged to `~/.bandwidth-monitor-YYYYMMDD.log`
- Timestamps for all entries
- Speed measurements
- Alert events

#### Dependencies

##### Required
- bc (basic calculator)
- nethogs (process bandwidth monitoring)
- iftop (network monitoring)
- mailutils (for email alerts)

#### Notes

- Some features require root privileges
- Email alerts require configured mail system
- Graphs work best in ANSI-compatible terminals
- Process monitoring requires sudo access
- Historical data requires logging enabled
- Interface must be active for monitoring

---

### 3. SSL Certificate Checker (`ssl-checker.sh`)

Advanced SSL certificate monitoring and analysis tool with comprehensive certificate management capabilities.

#### Features

- Certificate analysis:
  - Expiration monitoring
  - Chain verification
  - Protocol support
  - Cipher suites
- Security checks:
  - CRL verification
  - OCSP status
  - Chain validation
- Advanced features:
  - Batch processing
  - Email notifications
  - Certificate saving
  - Multiple output formats
- Detailed reporting
- Historical tracking

#### Installation

1. Ensure the script has executable permissions:
```bash
chmod +x ssl-checker.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install openssl curl jq bc

# For RHEL/CentOS
sudo yum install openssl curl jq bc
```

#### Usage

```bash
./ssl-checker.sh [OPTIONS] DOMAIN
```

##### Options

- `-p, --port PORT`        Port number (default: 443)
- `-w, --warning DAYS`     Days before expiry warning (default: 30)
- `-f, --format FORMAT`    Output format (text|json|csv)
- `-c, --chain`           Check certificate chain
- `-P, --protocols`       Check supported protocols
- `-C, --ciphers`         Check supported ciphers
- `-e, --email ADDRESS`    Email for alerts
- `-s, --save`            Save certificate to file
- `-r, --crl`             Check Certificate Revocation List
- `-o, --ocsp`            Check OCSP status
- `-b, --batch FILE`      Batch process domains from file
- `-v, --verbose`         Verbose output
- `-h, --help`            Show this help message

##### Examples

```bash
# Basic certificate check
./ssl-checker.sh example.com

# Full security analysis
./ssl-checker.sh -c -P -C -r -o example.com

# Batch processing with email alerts
./ssl-checker.sh -b domains.txt -e admin@example.com

# Save certificates with custom warning
./ssl-checker.sh -s -w 60 example.com

# Check with JSON output
./ssl-checker.sh -f json example.com
```

#### Output Formats

##### Text (default)
```
Domain: example.com
Expiry: Jan 14 12:00:00 2026 GMT
Days Left: 365
Issuer: CN=Let's Encrypt Authority X3
Subject: CN=example.com
```

##### JSON
```json
{
  "domain": "example.com",
  "expiry": "Jan 14 12:00:00 2026 GMT",
  "days_left": 365,
  "issuer": "CN=Let's Encrypt Authority X3",
  "subject": "CN=example.com"
}
```

##### CSV
```
example.com,Jan 14 12:00:00 2026 GMT,365,CN=Let's Encrypt Authority X3,CN=example.com
```

#### Batch Processing

Create a text file with domains:
```
example.com
subdomain.example.com
another-domain.com
```

Run batch check:
```bash
./ssl-checker.sh -b domains.txt
```

#### Alerts

- Expiration warnings
- Chain validation errors
- Protocol vulnerabilities
- Revocation status
- Email notifications

#### Logs

- All operations logged to `~/.ssl-checker-YYYYMMDD.log`
- Timestamps for all checks
- Certificate details
- Error messages

#### Dependencies

##### Required
- openssl
- curl
- jq (for JSON output)
- bc (for calculations)
- mailutils (for email alerts)

#### Notes

- Some checks require root privileges
- Email alerts require configured mail system
- Batch processing supports comments (#)
- Certificate saving creates PEM format
- OCSP checks require online access
- CRL checks may be slow for large lists

---

### 4. Port Scanner (`port-scanner.sh`)

Advanced port scanning utility with service detection and comprehensive scanning options.

#### Features

- Port scanning:
  - TCP/UDP scanning
  - Service detection
  - Port range support
  - Multi-threading
- Advanced features:
  - Batch scanning
  - Port exclusion
  - Custom timeouts
  - Multiple output formats
- Performance options:
  - Thread control
  - Timeout settings
  - Scan optimization
- Detailed reporting

#### Installation

1. Ensure the script has executable permissions:
```bash
chmod +x port-scanner.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install netcat-openbsd nmap parallel

# For RHEL/CentOS
sudo yum install nmap nc parallel
```

#### Usage

```bash
./port-scanner.sh [OPTIONS] TARGET
```

##### Options

- `-p, --ports RANGE`     Port range (default: 1-1024)
- `-t, --timeout SEC`     Connection timeout (default: 1)
- `-T, --threads NUM`     Number of threads (default: 10)
- `-f, --format FORMAT`   Output format (text|json|csv)
- `-s, --service`        Enable service detection
- `-o, --output FILE`    Save results to file
- `-x, --exclude PORTS`   Exclude specific ports
- `-b, --batch FILE`     Batch scan from file
- `-u, --udp`           Include UDP scan
- `-v, --verbose`        Verbose output
- `-h, --help`           Show this help message

##### Examples

```bash
# Basic scan of common ports
./port-scanner.sh example.com

# Full range scan with service detection
./port-scanner.sh -p 1-65535 -s example.com

# Fast scan with custom threads
./port-scanner.sh -T 50 -t 0.5 example.com

# Exclude specific ports
./port-scanner.sh -x "21,22,80" example.com

# Batch scanning with UDP
./port-scanner.sh -b targets.txt -u
```

#### Output Formats

##### Text (default)
```
Host                 Port   Status  Service
----------------------------------------
example.com         80     open    HTTP
example.com         443    open    HTTPS
```

##### JSON
```json
{
  "host": "example.com",
  "port": 80,
  "status": "open",
  "service": "HTTP"
}
```

##### CSV
```
example.com,80,open,HTTP
example.com,443,open,HTTPS
```

#### Logs

- All operations logged to `~/.port-scanner-YYYYMMDD.log`
- Timestamps for all scans
- Port status details
- Error messages

#### Dependencies

##### Required
- netcat (nc)
- nmap
- parallel
- basic Unix utilities

#### Notes

- Some scans require root privileges
- UDP scanning may be slower
- Service detection adds scan time
- Batch processing supports comments (#)
- Thread count affects system load
- Some firewalls may block scans

### 5. DNS Utilities (`dns-utils.sh`)

Comprehensive DNS lookup and analysis toolkit with advanced query capabilities.

#### Features

- DNS queries:
  - Multiple record types
  - Reverse lookups
  - Zone transfers
  - DNS tracing
- Advanced features:
  - Batch processing
  - Custom DNS servers
  - WHOIS integration
  - Multiple output formats
- Query options:
  - Record type selection
  - Server selection
  - Trace resolution
  - Zone transfer attempts
- Detailed reporting

#### Installation

1. Ensure the script has executable permissions:
```bash
chmod +x dns-utils.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install dnsutils whois

# For RHEL/CentOS
sudo yum install bind-utils whois
```

#### Usage

```bash
./dns-utils.sh [OPTIONS] DOMAIN
```

##### Options

- `-t, --type TYPE`       Record type (A|AAAA|MX|NS|TXT|SOA|ANY)
- `-s, --server DNS`      Specific DNS server
- `-f, --format FORMAT`   Output format (text|json|csv)
- `-o, --output FILE`     Save results to file
- `-a, --all`            Check all record types
- `-r, --reverse`        Reverse DNS lookup
- `-T, --trace`          Trace DNS resolution
- `-z, --zone`           Attempt zone transfer
- `-b, --batch FILE`     Batch process domains from file
- `-v, --verbose`        Verbose output
- `-h, --help`           Show this help message

##### Examples

```bash
# Basic DNS lookup
./dns-utils.sh example.com

# Check all record types
./dns-utils.sh -a example.com

# Use specific DNS server
./dns-utils.sh -s 8.8.8.8 -t MX example.com

# Reverse DNS lookup
./dns-utils.sh -r 8.8.8.8

# Trace DNS resolution
./dns-utils.sh -T example.com

# Batch processing with all records
./dns-utils.sh -b domains.txt -a
```

#### Output Formats

##### Text (default)
```
Domain                          Type   Result
------------------------------------------------
example.com                     A      93.184.216.34
example.com                     MX     10 mail.example.com
```

##### JSON
```json
{
  "domain": "example.com",
  "type": "A",
  "result": "93.184.216.34"
}
```

##### CSV
```
example.com,A,93.184.216.34
example.com,MX,10 mail.example.com
```

#### Logs

- All operations logged to `~/.dns-utils-YYYYMMDD.log`
- Timestamps for all queries
- Query results
- Error messages

#### Dependencies

##### Required
- dig (dnsutils)
- host
- nslookup
- whois

#### Notes

- Zone transfers may be restricted
- Some queries require root privileges
- WHOIS rate limits may apply
- Batch processing supports comments (#)
- Custom DNS servers may have restrictions
- Some record types may be filtered
