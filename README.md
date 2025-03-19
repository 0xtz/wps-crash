# WPS-Crash: Automated WPS Attack Tool

## Description

WPS-Crash is an open-source Bash script that automates attacks on WPS-enabled networks.
It attempts to brute-force the WPS PIN, exploit Pixie Dust vulnerabilities, and perform MAC address spoofing to bypass router lockouts.

## Features

- Scan for WPS-enabled networks
- Brute-force WPS PINs using Reaver
- Attempt Pixie Dust attack if available
- Automatically change MAC address to avoid detection
- Save scan results for manual review

## Installation

Ensure you have the required dependencies:

```bash
sudo apt update && sudo apt install -y aircrack-ng reaver wash macchanger bully
```

## Usage

1. Clone the repository:

```bash
git clone https://github.com/yourusername/wps-crash.git
cd wps-crash
```

2. Make the script executable:

```bash
chmod +x wps-crash.sh
```

3. Run the script as root:

```bash
sudo ./wps-crash.sh
```

4. Follow on-screen instructions to select a target and run attacks.

## Disclaimer

This tool is for educational and security testing purposes only. Do not use it on networks you do not own. The author is not responsible for any misuse.

## License

MIT License
