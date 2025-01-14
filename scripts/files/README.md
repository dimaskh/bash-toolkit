# File Management Scripts

A collection of advanced file management tools.

## Scripts

### 1. Duplicate File Finder (`duplicate-finder.sh`)

Advanced duplicate file finder with multiple hash algorithms and reporting.

#### Features

- Multiple hash algorithms (MD5, SHA1, SHA256, SHA512)
- Size-based pre-filtering
- Interactive deletion mode
- Multiple output formats (text, JSON, CSV)
- Content verification
- Exclude patterns
- Detailed logging

#### Usage

```bash
./duplicate-finder.sh [OPTIONS] DIRECTORY
```

### 2. Large File Finder (`large-file-finder.sh`)

Advanced large file locator with sorting and filtering capabilities.

#### Features

- Size-based filtering
- Multiple output formats
- File type filtering
- Group by type/directory
- Sort by size
- Exclude patterns
- Detailed logging

#### Usage

```bash
./large-file-finder.sh [OPTIONS] DIRECTORY
```

### 3. File Organizer (`file-organizer.sh`)

Advanced file organization tool with multiple organization strategies.

#### Features

- Organize by type, date, size, or name
- Multiple conflict resolution strategies
- Preserve directory structure
- Create symbolic links
- Move or copy files
- Dry-run mode
- Detailed logging

#### Usage

```bash
./file-organizer.sh [OPTIONS] SOURCE_DIR [TARGET_DIR]
```

### 4. Bulk File Renamer (`bulk-renamer.sh`)

Advanced bulk file renaming tool with multiple renaming strategies.

#### Features

- Pattern-based renaming
- Sequential numbering
- Date-based renaming
- Case conversion
- Name cleaning
- Preview mode
- Undo capability
- Detailed logging

#### Usage

```bash
./bulk-renamer.sh [OPTIONS] TARGET_DIR [PATTERN] [REPLACEMENT]
```

## Installation

1. Ensure all scripts have executable permissions:
```bash
chmod +x *.sh
```

2. Install required dependencies:
```bash
# For Debian/Ubuntu
sudo apt-get install coreutils findutils file bc jq

# For RHEL/CentOS
sudo yum install coreutils findutils file bc jq
```

## Common Features

All scripts include:

- Recursive operation
- Multiple output formats
- Exclude patterns
- Hidden file handling
- Symbolic link handling
- Detailed logging
- Dry-run mode

## Output Formats

- Text: Human-readable output
- JSON: Structured data format
- CSV: Spreadsheet-compatible format

## Security

- Safe file operations
- Dry-run mode
- Undo capability
- Detailed logging
- No sensitive data exposure

## Notes

- Test with dry-run first
- Back up important data
- Check disk space
- Monitor system resources
- Review logs regularly
