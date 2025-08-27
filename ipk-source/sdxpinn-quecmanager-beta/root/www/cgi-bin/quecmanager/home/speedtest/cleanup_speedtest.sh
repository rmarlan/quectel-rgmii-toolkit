#!/bin/sh
# Location: /www/cgi-bin/quecmanager/home/speedtest/cleanup_speedtest.sh

echo "Content-Type: application/json"
echo ""

# Configuration
STATUS_FILE="/tmp/speedtest_status.json"
FINAL_RESULT="/tmp/speedtest_final.json"
PID_FILE="/tmp/speedtest.pid"
LOG_FILE="/tmp/speedtest.log"

CLEANED_FILES=""
KILLED_PROCESSES=""

# Kill any running speedtest processes
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill -9 "$PID" 2>/dev/null
        KILLED_PROCESSES="$PID"
    fi
fi

# Also kill any speedtest processes that might be running without PID file
STRAY_PIDS=$(ps | grep speedtest | grep -v grep | awk '{print $1}' 2>/dev/null)
if [ -n "$STRAY_PIDS" ]; then
    for pid in $STRAY_PIDS; do
        kill -9 "$pid" 2>/dev/null
        if [ -n "$KILLED_PROCESSES" ]; then
            KILLED_PROCESSES="$KILLED_PROCESSES,$pid"
        else
            KILLED_PROCESSES="$pid"
        fi
    done
fi

# Remove all speedtest-related files
for file in "$STATUS_FILE" "$FINAL_RESULT" "$PID_FILE" "$LOG_FILE"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        if [ -n "$CLEANED_FILES" ]; then
            CLEANED_FILES="$CLEANED_FILES,$(basename $file)"
        else
            CLEANED_FILES="$(basename $file)"
        fi
    fi
done

# Prepare response
if [ -n "$CLEANED_FILES" ] || [ -n "$KILLED_PROCESSES" ]; then
    echo '{"status":"cleaned","message":"Cleanup completed","cleaned_files":"'$CLEANED_FILES'","killed_processes":"'$KILLED_PROCESSES'","timestamp":'$(date +%s)'}'
else
    echo '{"status":"clean","message":"No cleanup needed","timestamp":'$(date +%s)'}'
fi
