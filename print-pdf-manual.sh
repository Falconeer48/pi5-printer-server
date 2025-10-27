#!/bin/bash

# Manual PDF printing script for iMac
# This script monitors the IncomingPrints folder and prints any PDFs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

WATCHED_FOLDER="$HOME/IncomingPrints"
PRINTER="Canon_G4070_series"

print_status $BLUE "🖨️  Starting PDF printer monitor..."
print_status $BLUE "📁 Watching folder: $WATCHED_FOLDER"
print_status $BLUE "🖨️  Printer: $PRINTER"
echo ""

# Create the watched folder if it doesn't exist
mkdir -p "$WATCHED_FOLDER"

# Function to print a PDF
print_pdf() {
    local file="$1"
    local filename=$(basename "$file")
    
    print_status $BLUE "📄 Printing: $filename"
    
    if lp -d "$PRINTER" "$file"; then
        print_status $GREEN "✅ Successfully printed: $filename"
        echo "$(date): Printed $filename" >> "$WATCHED_FOLDER/print-log.txt"
    else
        print_status $RED "❌ Failed to print: $filename"
        echo "$(date): Failed to print $filename" >> "$WATCHED_FOLDER/print-log.txt"
    fi
}

# Function to monitor folder
monitor_folder() {
    print_status $BLUE "👀 Monitoring folder for new PDFs..."
    echo "Press Ctrl+C to stop"
    echo ""
    
    # Get initial list of files
    previous_files=$(ls "$WATCHED_FOLDER"/*.pdf 2>/dev/null | sort)
    
    while true; do
        # Get current list of files
        current_files=$(ls "$WATCHED_FOLDER"/*.pdf 2>/dev/null | sort)
        
        # Find new files
        new_files=$(comm -13 <(echo "$previous_files") <(echo "$current_files"))
        
        if [ -n "$new_files" ]; then
            echo "$new_files" | while read -r file; do
                if [ -f "$file" ]; then
                    print_pdf "$file"
                fi
            done
        fi
        
        # Update previous files list
        previous_files="$current_files"
        
        # Wait 2 seconds before checking again
        sleep 2
    done
}

# Check if we should run in background
if [ "$1" = "--background" ]; then
    print_status $YELLOW "🔄 Running in background mode..."
    nohup "$0" > "$WATCHED_FOLDER/printer-monitor.log" 2>&1 &
    echo $! > "$WATCHED_FOLDER/printer-monitor.pid"
    print_status $GREEN "✅ Printer monitor started in background"
    print_status $BLUE "📋 To stop: kill \$(cat $WATCHED_FOLDER/printer-monitor.pid)"
    print_status $BLUE "📋 To view log: tail -f $WATCHED_FOLDER/printer-monitor.log"
else
    monitor_folder
fi
