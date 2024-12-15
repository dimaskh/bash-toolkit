# Useful Bash Scripts Collection

A collection of everyday bash scripts for Unix-based systems (MacOS and Arch Linux).

## Installation

1. Clone this repository: 

```bash
git clone https://github.com/dimaskh/bash-toolkit.git
```

2. Navigate to the repository directory:

```bash
cd bash-toolkit
```

3. Make the scripts executable:

```bash
chmod +x *.sh
```

4. (Optional) Add scripts to your PATH by adding this line to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$PATH:/path/to/bash-scripts/scripts"
```

## Available Scripts

1. `system-info.sh` - Display system information including OS, memory, disk usage
2. `backup.sh` - Create compressed backups of specified directories
3. `cleanup.sh` - Clean temporary files and cached data
4. `monitor.sh` - Monitor system resources in real-time
5. `update-system.sh` - Update system packages (supports both MacOS and Arch Linux)

## Usage

Each script has its own documentation in the `docs` directory. See individual script documentation for specific usage instructions.

## Contributing

Feel free to submit issues and pull requests.

## License

MIT License