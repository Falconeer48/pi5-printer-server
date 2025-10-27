# Pi5 Printer Server

Print server setup for Canon G4470 printer using Raspberry Pi 5 as CUPS server.

## Overview

This repository contains scripts for printing from Mac Mini to a Canon G4470 printer via a Raspberry Pi 5 print server.

## Architecture

- **Mac Mini**: Sends print jobs
- **Pi5**: Print server running CUPS
- **Printer**: Canon G4470 (connected to Pi5)

## Scripts

### test-print-pi5.sh
Main printing script - uploads files to Pi5 and prints them.

**Usage**:
```bash
./test-print-pi5.sh <file> [copies]
./test-print-pi5.sh document.pdf
./test-print-pi5.sh photo.jpg 2
```

### diagnose-pi5-print.sh
Diagnostic tool to check Pi5 connectivity and printer status.

**Usage**:
```bash
./diagnose-pi5-print.sh
```

### check-pi-printer.sh
Quick status checker for the printer.

### reset-pi-printer.sh
Reset/restart the printer service on Pi5.

### print-pdf-manual.sh
Manual PDF printing utility.

### send-to-imac-printer.sh
Send files to iMac printer (alternative setup).

### setup-print.sh
Interactive setup script for printer configuration.

## Configuration

- **Pi5 Host**: ian@192.168.50.243
- **SSH Key**: ~/.ssh/id_ed25519
- **Printer Name**: Canon_G4470
- **CUPS Web Interface**: http://192.168.50.243:631

## Supported File Types

- PDF files
- Images: JPG, PNG, GIF, BMP, TIFF
- Documents: DOC, DOCX, TXT, RTF

## Requirements

- SSH access to Pi5
- CUPS installed on Pi5
- Canon G4470 printer connected to Pi5
- Printer drivers installed on Pi5

## Installation

1. Clone this repository
2. Ensure SSH keys are set up for Pi5 access
3. Make scripts executable: `chmod +x *.sh`
4. Run setup script: `./setup-print.sh`

## Troubleshooting

Run the diagnostic script to check connectivity:
```bash
./diagnose-pi5-print.sh
```

Check printer status on Pi5:
```bash
ssh ian@192.168.50.243 "lpstat -p"
```

Check CUPS status:
```bash
ssh ian@192.168.50.243 "systemctl status cups"
```
