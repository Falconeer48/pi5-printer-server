#!/bin/bash

# Test Print Script for Pi5 Print Server
# Usage: test-print-pi5.sh <file>

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PI5_HOST="ian@192.168.50.243"
SSH_KEY="~/.ssh/id_ed25519"
PRINTER_NAME="Canon_G4470"  # Adjust this to match your printer name

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to run command on Pi5
run_on_pi5() {
    ssh -i "$SSH_KEY" "$PI5_HOST" "$1"
}

# Function to print file
print_file() {
    local file="$1"
    local copies="${2:-1}"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        print_status "$RED" "❌ File not found: $file"
        exit 1
    fi
    
    # Get file info
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    local file_size_mb=$((file_size / 1024 / 1024))
    
    print_status "$BLUE" "🖨️  Printing: $(basename "$file")"
    print_status "$BLUE" "   Size: ${file_size_mb}MB"
    print_status "$BLUE" "   Copies: $copies"
    print_status "$BLUE" "   Printer: $PRINTER_NAME"
    
    # Create temporary filename on Pi5
    local temp_file="/tmp/$(basename "$file")_$(date +%s)"
    
    # Copy file to Pi5
    print_status "$BLUE" "📤 Copying file to Pi5..."
    if scp -i "$SSH_KEY" -o ConnectTimeout=10 "$file" "$PI5_HOST:$temp_file"; then
        print_status "$GREEN" "✅ File copied to Pi5"
        
        # Print file on Pi5
        print_status "$BLUE" "🖨️  Sending print job..."
        if run_on_pi5 "lp -d $PRINTER_NAME -n $copies '$temp_file'"; then
            print_status "$GREEN" "✅ Print job submitted successfully"
            
            # Clean up temp file
            run_on_pi5 "rm '$temp_file'" 2>/dev/null
            
            # Check print queue
            print_status "$BLUE" "📋 Checking print queue..."
            sleep 2
            QUEUE_STATUS=$(run_on_pi5 "lpstat -o 2>/dev/null")
            if [ -n "$QUEUE_STATUS" ]; then
                print_status "$YELLOW" "⚠️  Jobs still in queue:"
                echo "$QUEUE_STATUS"
            else
                print_status "$GREEN" "✅ Print job completed (not in queue)"
            fi
            
        else
            print_status "$RED" "❌ Failed to submit print job"
            run_on_pi5 "rm '$temp_file'" 2>/dev/null
            exit 1
        fi
    else
        print_status "$RED" "❌ Failed to copy file to Pi5"
        exit 1
    fi
}

# Main script logic
if [ $# -eq 0 ]; then
    print_status "$BLUE" "🖨️  Test Print to Pi5 Print Server"
    echo ""
    print_status "$BLUE" "Usage: $0 <file> [copies]"
    echo ""
    print_status "$BLUE" "Examples:"
    print_status "$BLUE" "  $0 document.pdf"
    print_status "$BLUE" "  $0 photo.jpg 2"
    echo ""
    print_status "$BLUE" "First run the diagnostic script:"
    print_status "$BLUE" "  ./diagnose-pi5-print.sh"
    exit 0
fi

# Check Pi5 connectivity first
print_status "$BLUE" "🔍 Checking Pi5 connectivity..."
if ! ping -c 1 -W 3 "192.168.50.243" >/dev/null 2>&1; then
    print_status "$RED" "❌ Cannot reach Pi5"
    exit 1
fi

if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o BatchMode=yes "$PI5_HOST" "echo 'SSH test'" >/dev/null 2>&1; then
    print_status "$RED" "❌ Cannot connect to Pi5 via SSH"
    exit 1
fi

print_status "$GREEN" "✅ Pi5 connectivity confirmed"

# Print the file
print_file "$1" "$2"

print_status "$GREEN" "🎉 Print test completed!"
