#!/bin/sh
# Location: /www/cgi-bin/quecmanager/home/speedtest/check_speedtest.sh

echo "Content-Type: application/json"
echo ""

# Check if speedtest binary exists and is executable
if ! command -v speedtest >/dev/null 2>&1; then
    echo '{"status":"error","message":"Speedtest binary not found in PATH","available":false}'
    exit 1
fi

# Get speedtest binary location
SPEEDTEST_PATH=$(which speedtest 2>/dev/null)

# Check if binary is executable
if [ ! -x "$SPEEDTEST_PATH" ]; then
    echo '{"status":"error","message":"Speedtest binary is not executable","available":false,"path":"'$SPEEDTEST_PATH'"}'
    exit 1
fi

# Try to get version (this also checks if binary works)
VERSION_OUTPUT=$(speedtest --version 2>/dev/null | head -1)
if [ $? -ne 0 ]; then
    echo '{"status":"error","message":"Speedtest binary exists but is not working properly","available":false,"path":"'$SPEEDTEST_PATH'"}'
    exit 1
fi

# Check if license is already accepted
LICENSE_CHECK=$(timeout 5 speedtest --accept-license --help 2>/dev/null | grep -i "usage\|help" | head -1)
if [ -z "$LICENSE_CHECK" ]; then
    echo '{"status":"warning","message":"Speedtest binary may need license acceptance","available":true,"path":"'$SPEEDTEST_PATH'","version":"'$VERSION_OUTPUT'"}'
else
    echo '{"status":"ok","message":"Speedtest is properly installed and ready","available":true,"path":"'$SPEEDTEST_PATH'","version":"'$VERSION_OUTPUT'"}'
fi
