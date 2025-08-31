#!/bin/sh

# Set content type to JSON
echo "Content-type: application/json" 
echo ""

# Configuration
QUEUE_DIR="/tmp/at_queue"
RESULTS_DIR="$QUEUE_DIR/results"
RESULT_FILE="/tmp/qscan_result.json"
PID_FILE="/tmp/cell_scan.pid"
TOKEN_FILE="$QUEUE_DIR/token"

# Function to log messages
log_message() {
    local level="${2:-info}"
    logger -t at_queue -p "daemon.$level" "check_scan: $1"
}

# Function to output JSON response
output_json() {
    local status="$1"
    local message="$2"

    if [ "$status" = "success" ] && [ -f "$RESULT_FILE" ]; then
        # Return the contents of the result file
        cat "$RESULT_FILE"
    else
        printf '{"status":"%s","message":"%s","timestamp":"","output":""}\n' "$status" "$message"
    fi
}

# Check for scan token holder
check_token_holder() {
    if [ -f "$TOKEN_FILE" ]; then
        local current_holder=$(cat "$TOKEN_FILE" | jsonfilter -e '@.id' 2>/dev/null)
        if [ -n "$current_holder" ] && echo "$current_holder" | grep -q "CELL_SCAN"; then
            log_message "Cell scan token is active: $current_holder" "debug"
            return 0
        fi
    fi
    return 1
}

# Check if a scan is already in progress
check_scan_progress() {
    # First check PID file
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "Scan in progress (PID: $pid)" "info"
            output_json "running" "Scan in progress"
            exit 0
        else
            log_message "Removing stale PID file" "warn"
            rm -f "$PID_FILE"
        fi
    fi

    # Also check token holder
    if check_token_holder; then
        log_message "Scan in progress (Token active)" "info"
        output_json "running" "Scan in progress (Token active)"
        exit 0
    fi
}

# Check for existing results
check_results() {
    if [ -f "$RESULT_FILE" ]; then
        rm -f "$RESULT_FILE"  # Remove the result file if it exists
        log_message "Result file removed" "info"
        output_json "success" "Scan results removed"
        exit 0
    else
        log_message "No result file found to clear" "info"
        output_json "success" "No result file to clear"
        exit 0
    fi
}

# Main execution
{
    # First check if a scan is in progress
    check_scan_progress

    # Then check for existing results
    check_results

    # If no results and no running scan, indicate idle state
    log_message "No active scan or recent results" "info"
    output_json "success" "No active scan"
    exit 0
} || {
    # Error handler
    log_message "Failed to remove scan results" "error"
    output_json "error" "Failed to remove scan results"
    exit 1
}