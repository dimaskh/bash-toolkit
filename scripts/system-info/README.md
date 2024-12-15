# System Information Script

## Description

`system-info.sh` is a bash script that displays comprehensive system information in a user-friendly format.

## Features

- Displays OS information
- Shows system uptime
- Reports memory usage
- Shows disk usage
- Displays CPU information

## Usage 

```bash
./system-info.sh
```

## Output Example

```
=== Operating System Information ===
PRETTY_NAME="Arch Linux"

=== System Uptime ===
 09:54:50 up  2:41,  2 users,  load average: 0.16, 0.25, 0.22

=== Memory Information ===
               total        used        free      shared  buff/cache   available
Mem:            62Gi       5.6Gi        51Gi       297Mi       7.0Gi        57Gi
Swap:             0B          0B          0B

=== Disk Usage ===
Filesystem      Size  Used Avail Use% Mounted on
dev              32G     0   32G   0% /dev
run              32G  1.5M   32G   1% /run
efivarfs        128K   29K   95K  24% /sys/firmware/efi/efivars
/dev/nvme0n1p2  931G  462G  468G  50% /
/dev/nvme0n1p2  931G  462G  468G  50% /.snapshots
/dev/nvme0n1p2  931G  462G  468G  50% /var/log
/dev/nvme0n1p2  931G  462G  468G  50% /var/cache/pacman/pkg
/dev/nvme0n1p2  931G  462G  468G  50% /home
/dev/nvme0n1p1 1022M  280M  743M  28% /boot

=== CPU Information ===
model name      : AMD Ryzen 9 5900X 12-Core Processor
CPU Cores: 24
```

## Platform Compatibility

- MacOS
- Linux (tested on Arch Linux)

## Dependencies

No external dependencies required. 