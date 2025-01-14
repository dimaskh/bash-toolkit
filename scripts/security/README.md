# Security Scripts

A collection of scripts for system security monitoring and management.

## Scripts

### 1. File Permission Auditor (`permission-auditor.sh`)

Advanced file permission and ownership auditing tool with comprehensive security checks.

#### Features

- Permission analysis:
  - SUID/SGID detection
  - World-writable files
  - Custom rule sets
  - Recursive scanning
- Security checks:
  - Permission validation
  - Ownership verification
  - Custom security rules
  - Recommendations
- Advanced features:
  - Batch processing
  - Multiple output formats
  - Pattern exclusion
  - Auto-fix options
- Detailed reporting

#### Usage

```bash
./permission-auditor.sh [OPTIONS] PATH
```

##### Options

- `-r, --recursive`        Recursive scan
- `-f, --format FORMAT`    Output format (text|json|csv)
- `-i, --ignore PATTERN`   Ignore pattern (glob)
- `-c, --custom FILE`      Custom rules file
- `-o, --output FILE`      Save results to file
- `--no-suid`             Skip SUID check
- `--no-sgid`             Skip SGID check
- `--no-world`            Skip world-writable check
- `--fix`                 Fix permissions (requires root)
- `--no-recommend`        Skip recommendations
- `-v, --verbose`         Verbose output

### 2. SSH Key Manager (`ssh-key-manager.sh`)

Comprehensive SSH key management and monitoring tool.

#### Features

- Key management:
  - Generation
  - Rotation
  - Backup/restore
  - Security checks
- Advanced features:
  - Multiple key types
  - Batch operations
  - Custom settings
  - Security monitoring
- Key operations:
  - List keys
  - Check security
  - Revoke keys
  - Monitor usage
- Detailed reporting

#### Usage

```bash
./ssh-key-manager.sh [OPTIONS] ACTION
```

##### Actions

- `generate`    Generate new SSH key pair
- `list`        List existing SSH keys
- `backup`      Backup SSH keys
- `restore`     Restore SSH keys from backup
- `check`       Check SSH key security
- `revoke`      Revoke SSH key
- `rotate`      Rotate SSH keys
- `scan`        Scan authorized_keys

##### Options

- `-t, --type TYPE`      Key type (rsa|ed25519|ecdsa)
- `-b, --bits BITS`      Key size (for RSA)
- `-n, --name NAME`      Key name
- `-c, --comment TEXT`   Key comment
- `-f, --format FORMAT`  Output format (text|json|csv)
- `-e, --expiry DAYS`    Check key expiry
- `--force`             Force operations
- `-v, --verbose`       Verbose output

### 3. Failed Login Monitor (`login-monitor.sh`)

Advanced failed login attempts monitoring and alerting tool.

#### Features

- Login monitoring:
  - Real-time tracking
  - Pattern detection
  - IP tracking
  - User tracking
- Security features:
  - IP blacklisting
  - Geolocation lookup
  - Email alerts
  - Custom thresholds
- Advanced options:
  - Multiple log sources
  - Custom time windows
  - Batch processing
  - Daemon mode
- Detailed reporting

#### Usage

```bash
./login-monitor.sh [OPTIONS]
```

##### Options

- `-w, --watch`           Watch mode (continuous monitoring)
- `-t, --threshold NUM`   Alert threshold (default: 5)
- `-T, --time SECONDS`    Time window in seconds (default: 300)
- `-e, --email ADDRESS`   Enable email alerts
- `-f, --format FORMAT`   Output format (text|json|csv)
- `-l, --log FILE`       Custom log file to monitor
- `-W, --whitelist FILE`  IP whitelist file
- `-B, --blacklist FILE`  IP blacklist file
- `-i, --ip-lookup`      Enable IP geolocation lookup
- `-o, --output FILE`    Save results to file
- `-d, --daemon`         Run in daemon mode
- `-v, --verbose`        Verbose output

### 4. Security Updates Checker (`security-updates.sh`)

Comprehensive security updates monitoring and management tool.

#### Features

- Update management:
  - Security updates
  - CVE tracking
  - Priority filtering
  - Auto-updates
- Advanced features:
  - Multiple formats
  - Email notifications
  - Custom repositories
  - Package exclusion
- Update operations:
  - Check updates
  - Install updates
  - View history
  - Track changes
- Detailed reporting

#### Usage

```bash
./security-updates.sh [OPTIONS] ACTION
```

##### Actions

- `check`       Check for security updates
- `list`        List available security updates
- `install`     Install security updates
- `history`     Show update history

##### Options

- `-f, --format FORMAT`   Output format (text|json|csv)
- `-e, --email ADDRESS`   Enable email alerts
- `-a, --auto`           Enable automatic updates
- `-c, --cve`            Check CVE references
- `-p, --priority`       Show only high priority updates
- `-r, --repo URL`       Custom repository URL
- `-x, --exclude PKGS`   Exclude packages (comma-separated)
- `-o, --output FILE`    Save results to file
- `-v, --verbose`        Verbose output

## Installation

1. Ensure scripts have executable permissions:
```bash
chmod +x *.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install geoip-bin mailutils

# For RHEL/CentOS
sudo yum install GeoIP mailx
```

## Notes

- Some scripts require root privileges
- Email alerts require configured mail system
- IP lookup requires GeoIP database
- Auto-updates should be used with caution
- Regular backups are recommended
- Monitor logs for any issues
