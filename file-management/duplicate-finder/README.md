# Duplicate File Finder

An advanced tool for finding and managing duplicate files in your filesystem.

## Features

- Multiple hash algorithms (MD5, SHA1, SHA256, SHA512)
- Size-based pre-filtering for efficiency
- Interactive deletion mode
- Multiple output formats (text, JSON, CSV)
- Content verification
- Exclude patterns
- Detailed logging
- Dry-run mode

## Usage

```bash
./duplicate-finder.sh [OPTIONS] DIRECTORY...

Options:
  -a, --algorithm ALG   Hash algorithm (md5|sha1|sha256|sha512)
  -s, --size SIZE      Minimum file size
  -i, --interactive    Interactive deletion mode
  -f, --format FMT     Output format (text|json|csv)
  -e, --exclude PAT    Exclude pattern (can be used multiple times)
  --verify            Verify file contents
  --dry-run           Don't make any changes
  --log FILE          Log file path
```

## Examples

1. Find duplicates using MD5 hash:
```bash
./duplicate-finder.sh -a md5 /path/to/directory
```

2. Find duplicates larger than 1MB:
```bash
./duplicate-finder.sh -s 1M /path/to/directory
```

3. Find duplicates with interactive deletion:
```bash
./duplicate-finder.sh -i /path/to/directory
```

## Output Formats

### Text Format
```
Group 1:
  - /path/to/file1.txt (1.2MB)
  - /path/to/file2.txt (1.2MB)

Group 2:
  - /path/to/file3.jpg (2.5MB)
  - /path/to/file4.jpg (2.5MB)
```

### JSON Format
```json
{
  "groups": [
    {
      "hash": "d41d8cd98f00b204e9800998ecf8427e",
      "size": 1258291,
      "files": [
        "/path/to/file1.txt",
        "/path/to/file2.txt"
      ]
    }
  ]
}
```

## Dependencies

- Standard Unix commands (`find`, `stat`, `file`)
- Hash utilities (md5sum, sha1sum, etc.)
- `jq` for JSON processing (optional)
