#!/bin/sh

# Smart Measurement Units Configuration Script
# Manages distance unit preferences (km/mi) with automatic timezone-based defaults
# Author: dr-dolomite
# Date: 2025-08-04

# Set content type and CORS headers
echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS"
echo "Access-Control-Allow-Headers: Content-Type"
echo ""

# Configuration
CONFIG_DIR="/etc/quecmanager/settings"
CONFIG_FILE="$CONFIG_DIR/measurement_units.conf"
LOG_FILE="/tmp/measurement_units.log"

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Error response function
send_error() {
    local error_code="$1"
    local error_message="$2"
    log_message "ERROR: $error_message"
    echo "{\"status\":\"error\",\"code\":\"$error_code\",\"message\":\"$error_message\"}"
    exit 1
}

# Success response function
send_success() {
    local message="$1"
    local data="$2"
    log_message "SUCCESS: $message"
    if [ -n "$data" ]; then
        echo "{\"status\":\"success\",\"message\":\"$message\",\"data\":$data}"
    else
        echo "{\"status\":\"success\",\"message\":\"$message\"}"
    fi
}

# Ensure configuration directory exists
ensure_config_directory() {
    if [ ! -d "$CONFIG_DIR" ]; then
        log_message "Creating directory: $CONFIG_DIR"
        mkdir -p "$CONFIG_DIR"
        if [ $? -ne 0 ]; then
            # Try to use a fallback location in /tmp
            CONFIG_DIR="/tmp/quecmanager/settings"
            CONFIG_FILE="$CONFIG_DIR/measurement_units.conf"
            log_message "Fallback to alternative location: $CONFIG_DIR"
            mkdir -p "$CONFIG_DIR"
            if [ $? -ne 0 ]; then
                send_error "DIRECTORY_ERROR" "Failed to create configuration directory"
            fi
        fi
        chmod 755 "$CONFIG_DIR"
        log_message "Created configuration directory: $CONFIG_DIR"
    fi
}

# Check if the country uses imperial or metric system based on timezone
get_default_unit() {
    # Get timezone from OpenWrt system - use uci as primary method
    local timezone=""
    
    # Primary method: Use uci command (standard OpenWrt way)
    if command -v uci >/dev/null 2>&1; then
        timezone=$(uci -q get system.@system[0].zonename)
        if [ -z "$timezone" ]; then
            timezone=$(uci -q get system.@system[0].timezone)
        fi
        log_message "Detected timezone using uci command: $timezone"
    fi
    
    # Fallback method: Parse OpenWrt config file directly
    if [ -z "$timezone" ] && [ -f "/etc/config/system" ]; then
        timezone=$(grep -o "option zonename '[^']*'" /etc/config/system | sed "s/option zonename '//;s/'//")
        
        if [ -z "$timezone" ]; then
            timezone=$(grep -o "option timezone '[^']*'" /etc/config/system | sed "s/option timezone '//;s/'//")
        fi
        log_message "Detected timezone from OpenWrt config file: $timezone"
    fi
    
    # Additional fallback methods
    if [ -z "$timezone" ]; then
        # Try TZ environment variable
        if [ -n "$TZ" ]; then
            timezone="$TZ"
            log_message "Detected timezone from TZ environment variable: $timezone"
        # Try /etc/TZ file
        elif [ -f "/etc/TZ" ]; then
            timezone=$(cat /etc/TZ)
            log_message "Detected timezone from /etc/TZ file: $timezone"
        fi
    fi
    
    # If still no timezone, use a default
    if [ -z "$timezone" ]; then
        timezone="Unknown"
        log_message "Warning: Could not detect timezone, using default (km)"
    fi
    
    # Countries and territories that primarily use imperial system (miles)
    # Based on current usage as of 2025:
    # - United States (including territories)
    # - Liberia 
    # - Myanmar/Burma (mixed usage, but officially imperial for distances)
    # - UK uses miles for road distances (though metric for most other measurements)
    # - Some British territories and dependencies
    case "$timezone" in
        # United States and territories - comprehensive timezone coverage
        *America/New_York*|*America/Chicago*|*America/Denver*|*America/Los_Angeles*|*America/Phoenix*|*America/Anchorage*|*America/Honolulu*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (US major cities)"
            ;;
        # All Americas timezones that are US-based
        *America/Adak*|*America/Juneau*|*America/Metlakatla*|*America/Nome*|*America/Sitka*|*America/Yakutat*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (US Alaska)"
            ;;
        # US territories in Pacific
        *Pacific/Honolulu*|*Pacific/Johnston*|*Pacific/Midway*|*Pacific/Wake*|*HST*|*Pacific/Samoa*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (US Pacific territories)"
            ;;
        # US territories in other regions
        *America/Puerto_Rico*|*America/Virgin*|*Atlantic/Bermuda*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (US territories)"
            ;;
        # General US timezone patterns
        *America/*EDT*|*America/*EST*|*America/*CDT*|*America/*CST*|*America/*MDT*|*America/*MST*|*America/*PDT*|*America/*PST*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (US timezone abbreviations)"
            ;;
        # Simple timezone abbreviations commonly used in US systems
        *EST*|*CST*|*MST*|*PST*|*EDT*|*CDT*|*MDT*|*PDT*|*AKST*|*AKDT*|*HST*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (US timezone codes)"
            ;;
        # United Kingdom - uses miles for road distances
        *Europe/London*|*GMT*|*BST*|*Europe/Belfast*|*Europe/Edinburgh*|*Europe/Cardiff*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (UK)"
            ;;
        # British territories and dependencies that use miles
        *Atlantic/Stanley*|*Indian/Chagos*|*Europe/Gibraltar*|*Atlantic/South_Georgia*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (British territories)"
            ;;
        # Liberia
        *Africa/Monrovia*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (Liberia)"
            ;;
        # Myanmar/Burma (mixed usage but officially uses imperial for some measurements)
        *Asia/Yangon*|*Asia/Rangoon*)
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (Myanmar)"
            ;;
        # OpenWrt config format with spaces (common in some router configurations)
        "America/New York"|"America/Los Angeles"|"America/Chicago"|"America/Denver"|"America/Phoenix"|"America/Anchorage"|"Europe/London")
            echo "mi"
            log_message "Default unit based on timezone ($timezone): miles (space-separated format)"
            ;;
        # Default to metric for all other countries/territories
        *)
            echo "km" 
            log_message "Default unit based on timezone ($timezone): kilometers (metric country)"
            ;;
    esac
}

# Get current measurement unit
get_measurement_unit() {
    # If config file exists, read from it
    if [ -f "$CONFIG_FILE" ]; then
        unit=$(grep "^DISTANCE_UNIT=" "$CONFIG_FILE" | cut -d'=' -f2)
        if [ -n "$unit" ]; then
            echo "$unit"
            return
        fi
    fi
    
    # If no config or empty config, determine default based on timezone
    get_default_unit
}

# Save measurement unit to config file
save_measurement_unit() {
    local unit="$1"
    ensure_config_directory
    
    # Create or update config file
    if [ -f "$CONFIG_FILE" ]; then
        # Update existing file
        sed -i "s/^DISTANCE_UNIT=.*$/DISTANCE_UNIT=$unit/" "$CONFIG_FILE"
        if [ $? -ne 0 ]; then
            # If sed fails (e.g., no match), append the setting
            echo "DISTANCE_UNIT=$unit" >> "$CONFIG_FILE"
        fi
    else
        # Create new file
        echo "DISTANCE_UNIT=$unit" > "$CONFIG_FILE"
    fi
    
    chmod 644 "$CONFIG_FILE"
    log_message "Saved distance unit: $unit"
}

# Delete measurement unit configuration
delete_measurement_unit() {
    if [ -f "$CONFIG_FILE" ]; then
        # Remove the DISTANCE_UNIT line
        sed -i '/^DISTANCE_UNIT=/d' "$CONFIG_FILE"
        log_message "Deleted distance unit configuration"
        
        # If file is empty after deletion, remove it
        if [ ! -s "$CONFIG_FILE" ]; then
            rm -f "$CONFIG_FILE"
            log_message "Removed empty config file"
        fi
        return 0
    else
        return 1
    fi
}

# Handle GET request - Retrieve measurement unit preference
handle_get() {
    log_message "GET request received"
    
    # Check if this is a debug request
    if echo "$QUERY_STRING" | grep -q "debug=1"; then
        # Return diagnostic information
        local timezone_info=""
        
        if command -v uci >/dev/null 2>&1; then
            timezone_info="$timezone_info\"uci_system_zonename\": \"$(uci -q get system.@system[0].zonename || echo 'Not found')\","
            timezone_info="$timezone_info\"uci_system_timezone\": \"$(uci -q get system.@system[0].timezone || echo 'Not found')\","
        else
            timezone_info="$timezone_info\"uci\": \"Command not found\","
        fi
        
        if [ -f "/etc/config/system" ]; then
            timezone_info="$timezone_info\"openwrt_config\": \"$(cat /etc/config/system | grep -E 'zonename|timezone' | tr '\n' ' ' | sed 's/"/\\"/g')\","
        else
            timezone_info="$timezone_info\"openwrt_config\": \"Not found\","
        fi
        
        if [ -n "$TZ" ]; then
            timezone_info="$timezone_info\"TZ_env\": \"$TZ\","
        else
            timezone_info="$timezone_info\"TZ_env\": \"Not set\","
        fi
        
        if [ -f "/etc/TZ" ]; then
            timezone_info="$timezone_info\"etc_TZ\": \"$(cat /etc/TZ)\","
        else
            timezone_info="$timezone_info\"etc_TZ\": \"Not found\","
        fi
        
        # Get default unit
        local default_unit=$(get_default_unit)
        
        # Remove trailing comma
        timezone_info=$(echo "$timezone_info" | sed 's/,$//')
        
        send_success "Debug information" "{$timezone_info, \"default_unit\": \"$default_unit\"}"
        return
    fi
    
    # Get current unit (from config or default)
    local unit=$(get_measurement_unit)
    
    # Check if it's from config or default
    local is_default=true
    if [ -f "$CONFIG_FILE" ] && grep -q "^DISTANCE_UNIT=" "$CONFIG_FILE"; then
        is_default=false
    fi
    
    send_success "Measurement unit retrieved" "{\"unit\":\"$unit\",\"isDefault\":$is_default}"
}

# Handle POST request - Update measurement unit preference
handle_post() {
    log_message "POST request received"
    
    # Read POST data
    local content_length=${CONTENT_LENGTH:-0}
    if [ "$content_length" -gt 0 ]; then
        local post_data=$(dd bs=$content_length count=1 2>/dev/null)
        log_message "Received POST data: $post_data"
        
        # Multiple approaches to parse JSON, for robustness across various OpenWrt versions
        # Approach 1: Simple regex extraction
        local unit=$(echo "$post_data" | sed -n 's/.*"unit"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        
        # Approach 2: grep + cut extraction
        if [ -z "$unit" ]; then
            unit=$(echo "$post_data" | grep -o '"unit":"[^"]*"' | cut -d'"' -f4)
        fi
        
        # Approach 3: Very basic extraction - look for km or mi in the payload
        if [ -z "$unit" ]; then
            if echo "$post_data" | grep -q '"km"'; then
                unit="km"
            elif echo "$post_data" | grep -q '"mi"'; then
                unit="mi"
            fi
        fi
        
        log_message "Received unit: $unit"
        
        # Validate unit
        if [ "$unit" = "km" ] || [ "$unit" = "mi" ]; then
            save_measurement_unit "$unit"
            send_success "Measurement unit updated successfully" "{\"unit\":\"$unit\"}"
        else
            send_error "INVALID_UNIT" "Invalid unit provided. Must be 'km' or 'mi'."
        fi
    else
        send_error "NO_DATA" "No data provided"
    fi
}

# Handle DELETE request - Reset to default (delete configuration)
handle_delete() {
    log_message "DELETE request received"
    
    if delete_measurement_unit; then
        # Get the default unit that will be used
        local default_unit=$(get_default_unit)
        send_success "Measurement unit reset to default" "{\"unit\":\"$default_unit\",\"isDefault\":true}"
    else
        send_error "NOT_FOUND" "Measurement unit configuration not found"
    fi
}

# Handle OPTIONS request for CORS preflight
handle_options() {
    log_message "OPTIONS request received"
    echo "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS"
    echo "Access-Control-Allow-Headers: Content-Type"
    echo "Access-Control-Max-Age: 86400"
    exit 0
}

# Main execution
log_message "Measurement units script called with method: ${REQUEST_METHOD:-GET}"

# Handle different HTTP methods
case "${REQUEST_METHOD:-GET}" in
    GET)
        handle_get
        ;;
    POST)
        handle_post
        ;;
    DELETE)
        handle_delete
        ;;
    OPTIONS)
        handle_options
        ;;
    *)
        send_error "METHOD_NOT_ALLOWED" "HTTP method ${REQUEST_METHOD} not supported"
        ;;
esac
