#!/bin/bash

# Send file to iMac printer via watched folder
# Usage: send-to-imac-printer.sh <file>

# Configuration
IMAC_USER="iancook"
IMAC_HOST="Ians-iMac.local"
WATCHED_SUBDIR="IncomingPrints"
WATCHED_FOLDER_REMOTE="$HOME/$WATCHED_SUBDIR"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if file is provided
if [[ $# -lt 1 ]]; then
    print_status "$RED" "❌ Usage: $0 <file>"
    print_status "$BLUE" "📖 Examples:"
    print_status "$BLUE" "  $0 document.pdf"
    print_status "$BLUE" "  $0 ~/Desktop/photo.jpg"
    exit 2
fi

FILE_PATH="$1"

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    print_status "$RED" "❌ File not found: $FILE_PATH"
    exit 1
fi

# Get file info
FILE_NAME=$(basename "$FILE_PATH")
FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null)
FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))

print_status "$BLUE" "📄 Sending: $FILE_NAME (${FILE_SIZE_MB}MB)"
print_status "$BLUE" "🎯 Target: $IMAC_USER@$IMAC_HOST:$WATCHED_FOLDER_REMOTE"

# Send file to iMac watched folder
if scp -q "$FILE_PATH" "$IMAC_USER@$IMAC_HOST:$WATCHED_FOLDER_REMOTE/"; then
    print_status "$GREEN" "✅ File sent successfully!"
    print_status "$BLUE" "🖨️  iMac should print automatically within a few seconds"
    
    # Optional: Check if file was processed
    print_status "$BLUE" "⏳ Checking print status..."
    sleep 2
    
    # Check the print log on iMac
    LOG_CONTENT=$(ssh -q "$IMAC_USER@$IMAC_HOST" "tail -1 \"$HOME/$WATCHED_SUBDIR/print-log.txt\" 2>/dev/null" 2>/dev/null)
    if [[ -n "$LOG_CONTENT" ]]; then
        if [[ "$LOG_CONTENT" == *"Printed $FILE_NAME"* ]]; then
            print_status "$GREEN" "✅ Print job confirmed in log"
        elif [[ "$LOG_CONTENT" == *"Skipped"* ]]; then
            print_status "$YELLOW" "⚠️  File skipped (unsupported format)"
        else
            print_status "$BLUE" "📋 Log entry: $LOG_CONTENT"
        fi
    fi
else
    print_status "$RED" "❌ Failed to send file to iMac"
    print_status "$YELLOW" "💡 Check:"
    print_status "$YELLOW" "   - iMac is reachable"
    print_status "$YELLOW" "   - SSH key authentication is set up"
    print_status "$YELLOW" "   - Watched folder exists on iMac"
    exit 1
fi




