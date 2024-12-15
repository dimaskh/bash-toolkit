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
find . -name "*.sh" -type f -exec chmod +x {} \;
```

4. (Optional) Add scripts to your PATH by adding this line to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$PATH:/path/to/bash-toolkit/scripts"
```

## Project Structure

```
bash-toolkit/
├── README.md
├── scripts/
│   ├── system-info/
│   │   ├── system-info.sh
│   │   └── README.md
│   ├── backup/
│   │   ├── backup.sh
│   │   └── README.md
│   ├── cleanup/
│   │   ├── cleanup.sh
│   │   └── README.md
│   ├── monitor/
│   │   ├── monitor.sh
│   │   └── README.md
│   └── update-system/
│       ├── update-system.sh
│       └── README.md
```

## Available Scripts

1. `system-info/system-info.sh` - Display system information including OS, memory, disk usage
2. `backup/backup.sh` - Create compressed backups of specified directories
3. `cleanup/cleanup.sh` - Clean temporary files and cached data
4. `monitor/monitor.sh` - Monitor system resources in real-time
5. `update-system/update-system.sh` - Update system packages (supports both MacOS and Arch Linux)

## Usage

Each script has its own README.md file in its directory with specific usage instructions.

## Contributing

Feel free to submit issues and pull requests.

## License

MIT License