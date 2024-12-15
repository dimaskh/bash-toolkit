#!/bin/bash

# System Information Script
# This script displays various system information including OS, memory, and disk usage

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Operating System Information
print_header "Operating System Information"
if [[ "$OSTYPE" == "darwin"* ]]; then
    sw_vers
else
    cat /etc/os-release | grep PRETTY_NAME
fi

# System Uptime
print_header "System Uptime"
uptime

# Memory Information
print_header "Memory Information"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # MacOS memory info
    vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'
else
    # Linux memory info
    free -h
fi

# Disk Usage
print_header "Disk Usage"
df -h | grep -v "tmpfs"

# CPU Information
print_header "CPU Information"
if [[ "$OSTYPE" == "darwin"* ]]; then
    sysctl -n machdep.cpu.brand_string
    echo "CPU Cores: $(sysctl -n hw.ncpu)"
else
    cat /proc/cpuinfo | grep "model name" | head -n 1
    echo "CPU Cores: $(nproc)"
fi 