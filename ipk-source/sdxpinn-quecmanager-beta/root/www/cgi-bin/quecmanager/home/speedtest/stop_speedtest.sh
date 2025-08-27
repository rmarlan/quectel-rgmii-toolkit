#!/bin/sh
# Location: /www/cgi-bin/quecmanager/home/speedtest/stop_speedtest.sh

# Configuration
STATUS_FILE="/tmp/speedtest_status.json"
FINAL_RESULT="/tmp/speedtest_final.json"
PID_FILE="/tmp/speedtest.pid"
LOG_FILE="/tmp/speedtest.log"

# Set headers
echo "Content-Type: application/json"
echo ""

# Function to cleanup all speedtest files
cleanup_all() {
    rm -f "$STATUS_FILE" "$FINAL_RESULT" "$PID_FILE" "$LOG_FILE"
}

# Check if speedtest is running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        # Kill the process
        kill "$PID" 2>/dev/null
        sleep 1
        
        # Force kill if still running
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID" 2>/dev/null
        fi
        
        # Wait for process to die
        count=0
        while kill -0 "$PID" 2>/dev/null && [ $count -lt 5 ]; do
            sleep 1
            count=$((count + 1))
        done
        
        # Log the cancellation
        echo "Speedtest cancelled at $(date)" >> "$LOG_FILE" 2>/dev/null
        
        # Cleanup files
        cleanup_all
        
        echo '{"status":"cancelled","message":"Speedtest cancelled successfully","timestamp":'$(date +%s)'}'
    else
        # PID file exists but process is not running
        cleanup_all
        echo '{"status":"not_running","message":"No active speedtest found","timestamp":'$(date +%s)'}'
    fi
else
    # No PID file, cleanup any stale files
    cleanup_all
    echo '{"status":"not_running","message":"No active speedtest found","timestamp":'$(date +%s)'}'
fi
