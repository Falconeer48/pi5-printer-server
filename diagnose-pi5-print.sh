#!/bin/bash

# Pi5 Print Server Diagnostic Script
# This script checks the status of your Pi5 print server and helps troubleshoot printing issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PI5_HOST="ian@192.168.50.243"
SSH_KEY="~/.ssh/id_ed25519"

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo ""
    print_status "$BLUE" "=========================================="
    print_status "$BLUE" "$1"
    print_status "$BLUE" "=========================================="
}

# Function to run command on Pi5
run_on_pi5() {
    ssh -i "$SSH_KEY" "$PI5_HOST" "$1"
}

# Function to check if command succeeded
check_command() {
    if [ $? -eq 0 ]; then
        print_status "$GREEN" "✅ $1"
    else
        print_status "$RED" "❌ $1"
    fi
}

print_header "Pi5 Print Server Diagnostic"
echo ""

# 1. Check Pi5 connectivity
print_header "1. Pi5 Connectivity Check"
print_status "$BLUE" "Testing connection to Pi5..."

if ping -c 1 -W 3 "192.168.50.243" >/dev/null 2>&1; then
    print_status "$GREEN" "✅ Pi5 is reachable via ping"
else
    print_status "$RED" "❌ Cannot ping Pi5"
    exit 1
fi

if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o BatchMode=yes "$PI5_HOST" "echo 'SSH test successful'" >/dev/null 2>&1; then
    print_status "$GREEN" "✅ SSH connection to Pi5 successful"
else
    print_status "$RED" "❌ SSH connection to Pi5 failed"
    exit 1
fi

# 2. Check CUPS service status
print_header "2. CUPS Service Status"
print_status "$BLUE" "Checking CUPS service..."

CUPS_STATUS=$(run_on_pi5 "systemctl is-active cups")
if [ "$CUPS_STATUS" = "active" ]; then
    print_status "$GREEN" "✅ CUPS service is running"
else
    print_status "$RED" "❌ CUPS service is not running (status: $CUPS_STATUS)"
    print_status "$YELLOW" "💡 Try: ssh $PI5_HOST 'sudo systemctl start cups'"
fi

CUPS_ENABLED=$(run_on_pi5 "systemctl is-enabled cups")
if [ "$CUPS_ENABLED" = "enabled" ]; then
    print_status "$GREEN" "✅ CUPS service is enabled for auto-start"
else
    print_status "$YELLOW" "⚠️  CUPS service is not enabled for auto-start"
    print_status "$YELLOW" "💡 Try: ssh $PI5_HOST 'sudo systemctl enable cups'"
fi

# 3. Check CUPS web interface
print_header "3. CUPS Web Interface"
print_status "$BLUE" "Testing CUPS web interface..."

if run_on_pi5 "curl -s http://localhost:631 >/dev/null 2>&1"; then
    print_status "$GREEN" "✅ CUPS web interface is accessible locally"
    print_status "$BLUE" "   URL: http://192.168.50.243:631"
else
    print_status "$RED" "❌ CUPS web interface is not accessible"
fi

# 4. Check installed printers
print_header "4. Installed Printers"
print_status "$BLUE" "Listing installed printers..."

PRINTERS=$(run_on_pi5 "lpstat -p 2>/dev/null")
if [ -n "$PRINTERS" ]; then
    print_status "$GREEN" "✅ Found printers:"
    echo "$PRINTERS" | while read -r line; do
        if [[ $line == *"printer"* ]]; then
            printer_name=$(echo "$line" | awk '{print $2}')
            print_status "$GREEN" "   📄 $printer_name"
        fi
    done
else
    print_status "$RED" "❌ No printers found"
    print_status "$YELLOW" "💡 You may need to add the Canon printer"
fi

# 5. Check printer status
print_header "5. Printer Status"
print_status "$BLUE" "Checking printer status..."

if run_on_pi5 "lpstat -t" >/dev/null 2>&1; then
    print_status "$GREEN" "✅ Printer status command successful"
    print_status "$BLUE" "Detailed printer status:"
    run_on_pi5 "lpstat -t"
else
    print_status "$RED" "❌ Cannot get printer status"
fi

# 6. Check print queue
print_header "6. Print Queue Status"
print_status "$BLUE" "Checking print queue..."

QUEUE_STATUS=$(run_on_pi5 "lpstat -o 2>/dev/null")
if [ -n "$QUEUE_STATUS" ]; then
    print_status "$YELLOW" "⚠️  Jobs in print queue:"
    echo "$QUEUE_STATUS"
else
    print_status "$GREEN" "✅ Print queue is empty"
fi

# 7. Check CUPS error logs
print_header "7. CUPS Error Logs"
print_status "$BLUE" "Checking recent CUPS errors..."

ERROR_LOG=$(run_on_pi5 "sudo tail -20 /var/log/cups/error_log 2>/dev/null")
if [ -n "$ERROR_LOG" ]; then
    print_status "$YELLOW" "Recent CUPS errors:"
    echo "$ERROR_LOG"
else
    print_status "$GREEN" "✅ No recent CUPS errors found"
fi

# 8. Test print capability
print_header "8. Test Print Capability"
print_status "$BLUE" "Testing basic print functionality..."

# Create a simple test file
TEST_FILE="/tmp/test_print.txt"
echo "Test print from Pi5 - $(date)" > "$TEST_FILE"

# Try to print the test file
if run_on_pi5 "echo 'Test print from Pi5 - $(date)' | lp"; then
    print_status "$GREEN" "✅ Test print job submitted successfully"
    
    # Wait a moment and check if it printed
    sleep 3
    QUEUE_CHECK=$(run_on_pi5 "lpstat -o 2>/dev/null")
    if [ -z "$QUEUE_CHECK" ]; then
        print_status "$GREEN" "✅ Test print job completed (not in queue)"
    else
        print_status "$YELLOW" "⚠️  Test print job still in queue"
        echo "$QUEUE_CHECK"
    fi
else
    print_status "$RED" "❌ Failed to submit test print job"
fi

# Clean up test file
rm -f "$TEST_FILE"

# 9. Network printer connectivity
print_header "9. Network Printer Connectivity"
print_status "$BLUE" "Checking network printer connectivity..."

# Try to detect Canon printer on network
print_status "$BLUE" "Scanning for Canon printers on network..."
NETWORK_PRINTERS=$(run_on_pi5 "lpinfo -v 2>/dev/null | grep -i canon")
if [ -n "$NETWORK_PRINTERS" ]; then
    print_status "$GREEN" "✅ Found Canon printers on network:"
    echo "$NETWORK_PRINTERS"
else
    print_status "$YELLOW" "⚠️  No Canon printers detected on network"
    print_status "$YELLOW" "💡 Make sure printer is connected to WiFi/Ethernet"
fi

# 10. Recommendations
print_header "10. Recommendations"
print_status "$BLUE" "Based on the diagnostic results:"

if [ "$CUPS_STATUS" != "active" ]; then
    print_status "$YELLOW" "🔧 Start CUPS service:"
    print_status "$YELLOW" "   ssh $PI5_HOST 'sudo systemctl start cups'"
fi

if [ -z "$PRINTERS" ]; then
    print_status "$YELLOW" "🔧 Add Canon printer:"
    print_status "$YELLOW" "   1. Open http://192.168.50.243:631 in browser"
    print_status "$YELLOW" "   2. Go to Administration → Add Printer"
    print_status "$YELLOW" "   3. Select Network Printer or IPP"
    print_status "$YELLOW" "   4. Enter printer IP address"
    print_status "$YELLOW" "   5. Select Canon PIXMA G4470 driver"
fi

print_status "$BLUE" "🔧 For troubleshooting:"
print_status "$BLUE" "   - Check printer IP: ssh $PI5_HOST 'lpinfo -v'"
print_status "$BLUE" "   - View CUPS logs: ssh $PI5_HOST 'sudo tail -f /var/log/cups/error_log'"
print_status "$BLUE" "   - Test print: ssh $PI5_HOST 'echo \"test\" | lp'"

print_header "Diagnostic Complete"
print_status "$GREEN" "✅ Pi5 print server diagnostic completed!"
echo ""


