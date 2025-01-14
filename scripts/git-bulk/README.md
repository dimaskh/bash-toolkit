# Git Bulk Operations Script

A powerful script for managing multiple Git repositories simultaneously, allowing bulk operations with advanced control options.

## Features

- Multiple Git operations support:
  - Status checking
  - Fetching/Pulling/Pushing
  - Branch checkout
  - Repository cleaning
  - Branch information
  - Stash management
- Recursive repository search
- Parallel execution option
- Dry-run mode
- Detailed logging
- Configurable search depth
- Remote repository specification
- Color-coded output
- Verbose mode for debugging

## Installation

1. Ensure the script has executable permissions:
```bash
chmod +x git-bulk.sh
```

2. Optionally, add to your PATH for system-wide access.

## Usage

```bash
./git-bulk.sh [OPTIONS] COMMAND
```

### Commands

- `status`              Show status of all repositories
- `fetch [remote]`      Fetch from remote
- `pull [remote]`       Pull from remote
- `push [remote]`       Push to remote
- `checkout <branch>`   Checkout branch
- `clean`              Remove untracked files
- `reset`              Reset to HEAD
- `branch`             Show current branch of all repositories
- `stash`              Stash changes
- `unstash`            Pop stashed changes

### Options

- `-d, --directory DIR`    Base directory (default: current)
- `-r, --recursive`        Search recursively
- `-m, --max-depth N`      Maximum recursion depth (default: 3)
- `-p, --parallel`         Run operations in parallel
- `-n, --dry-run`          Show what would be done
- `-v, --verbose`          Verbose output
- `-h, --help`             Show this help message

### Examples

```bash
# Check status of all repositories in current directory
./git-bulk.sh status

# Pull from origin in all repositories recursively
./git-bulk.sh -r pull

# Checkout a branch in all repositories with dry-run
./git-bulk.sh -n checkout develop

# Push to specific remote in parallel
./git-bulk.sh -p push upstream

# Show current branch of all repos in specific directory
./git-bulk.sh -d /path/to/repos branch

# Clean all repositories recursively with max depth 2
./git-bulk.sh -r -m 2 clean
```

## Operation Details

The script performs the following steps:
1. Searches for Git repositories in the specified directory
2. Validates each repository
3. Executes the requested Git command on each repository
4. Logs all operations and their results

## Logs

- All operations are logged to `~/.git-bulk-YYYYMMDD.log`
- Logs include timestamps and operation details
- Each command execution is documented with its result

## Dependencies

### Required
- Git
- Standard Unix utilities (find, cd, etc.)

## Notes

- Use dry-run mode (-n) first to preview operations
- Parallel mode can significantly speed up operations but may make output harder to read
- The script respects existing Git configurations in each repository
- Remote operations (fetch/pull/push) default to 'origin' if not specified
- Clean and reset operations are destructive - use with caution
- Log files are created in the user's home directory
- Color output works best in terminals supporting ANSI colors
