# Backup and Recovery Scripts

A collection of comprehensive backup and recovery scripts for system administration.

## Scripts

### 1. Incremental Backup (`incremental-backup.sh`)

Advanced incremental backup system with versioning and compression.

#### Features

- Incremental backups with rsync
- Multiple compression options
- Encryption support
- Email notifications
- Backup verification
- Retention policies
- Snapshot support
- Detailed logging

#### Usage

```bash
./incremental-backup.sh [OPTIONS] SOURCE_DIR BACKUP_DIR
```

### 2. Database Backup (`db-backup.sh`)

Multi-database backup automation tool.

#### Features

- Supports multiple databases:
  - MySQL/MariaDB
  - PostgreSQL
  - MongoDB
  - Redis
- Table filtering
- Compression options
- Encryption support
- Email notifications
- Backup verification
- Retention policies
- Detailed logging

#### Usage

```bash
./db-backup.sh [OPTIONS] DB_TYPE BACKUP_DIR
```

### 3. Config Backup (`config-backup.sh`)

Configuration files backup and versioning tool.

#### Features

- Multiple config directories
- Git version control
- Pattern exclusion
- Compression options
- Encryption support
- Email notifications
- Backup verification
- Retention policies
- Detailed logging

#### Usage

```bash
./config-backup.sh [OPTIONS] BACKUP_DIR [CONFIG_DIRS...]
```

### 4. Restore Point (`restore-point.sh`)

System restore point creator and manager.

#### Features

- System state snapshots
- Multiple restore points
- Selective restoration
- Point verification
- Compression options
- Encryption support
- Email notifications
- Retention policies
- Detailed logging

#### Usage

```bash
./restore-point.sh [OPTIONS] ACTION RESTORE_DIR
```

## Installation

1. Ensure all scripts have executable permissions:
```bash
chmod +x *.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install rsync tar gzip bzip2 xz-utils openssl mailutils

# For RHEL/CentOS
sudo yum install rsync tar gzip bzip2 xz openssl mailx
```

## Common Features

All scripts include:

- Comprehensive logging
- Multiple compression algorithms
- Encryption support
- Email notifications
- Backup verification
- Retention policies
- Dry-run mode
- Verbose output option

## Security

- All scripts support encryption using AES-256-CBC
- Sensitive data is handled securely
- Backup files are protected
- Logs contain no sensitive information

## Notes

- Some scripts require root privileges
- Email alerts require configured mail system
- Regular testing of backups is recommended
- Monitor disk space usage
- Keep encryption keys secure
- Verify backups periodically
