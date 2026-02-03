#!/bin/bash

# WiFi network picker using choose
# Shows saved networks and allows connecting to them

INTERFACE="en0"
LOG_FILE="/tmp/choose-wifi.log"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

log "=== WiFi picker started ==="

# Get current connected network
get_current_network() {
    local result
    result=$(networksetup -getairportnetwork "$INTERFACE" 2>/dev/null)
    if [[ "$result" == *"not associated"* ]]; then
        echo ""
    else
        echo "$result" | sed 's/Current Wi-Fi Network: //'
    fi
}

# Check if WiFi is enabled
is_wifi_on() {
    networksetup -getairportpower "$INTERFACE" 2>/dev/null | grep -q "On"
}

# Get saved password from keychain
get_saved_password() {
    local ssid="$1"
    security find-generic-password -D "AirPort network password" -a "$ssid" -gw 2>/dev/null
}

# Build JSON array of networks
build_network_json() {
    local current="$1"
    local first=true
    
    echo "["
    
    # Add disconnect option if connected
    if [[ -n "$current" ]]; then
        echo '  {"id":"disconnect","name":"Disconnect","subtitle":"Currently: '"$current"'","icon":"wifi.slash"}'
        first=false
    fi
    
    # Add saved networks
    networksetup -listpreferredwirelessnetworks "$INTERFACE" 2>/dev/null | tail -n +2 | while read -r ssid; do
        ssid="${ssid#"${ssid%%[![:space:]]*}"}"
        ssid="${ssid%"${ssid##*[![:space:]]}"}"
        [[ -z "$ssid" ]] && continue
        
        # Determine icon and subtitle
        local icon="wifi"
        local subtitle="Saved"
        if [[ "$ssid" =~ (iPhone|iPad|Android|Pixel|Galaxy|Phone|Hotspot|Mobile) ]]; then
            icon="antenna.radiowaves.left.and.right"
            subtitle="Hotspot"
        fi
        
        # Mark current network
        if [[ "$ssid" == "$current" ]]; then
            subtitle="✓ Connected"
        fi
        
        if [[ "$first" == "false" ]]; then
            echo ","
        fi
        first=false
        
        # Escape quotes in SSID for JSON
        local escaped_ssid="${ssid//\"/\\\"}"
        printf '  {"id":"connect","name":"%s","subtitle":"%s","icon":"%s"}' "$escaped_ssid" "$subtitle" "$icon"
    done
    
    # Add system settings option
    echo ','
    echo '  {"id":"settings","name":"System WiFi Settings","subtitle":"Scan for new networks","icon":"gear"}'
    echo "]"
}

# Convert JSON to choose format (name\tsubtitle\ticon)
json_to_choose() {
    jq -r '.[] | "\(.name)\t\(.subtitle)\t\(.icon)"'
}

# Check WiFi status
if ! is_wifi_on; then
    log "WiFi is off, prompting to enable"
    result=$(printf "Turn WiFi On\tWiFi is currently off\twifi.slash" | choose -p "WiFi")
    if [[ -n "$result" ]]; then
        networksetup -setairportpower "$INTERFACE" on
        osascript -e 'display notification "WiFi turned on" with title "WiFi"'
    fi
    exit 0
fi

# Get current network
current=$(get_current_network)
log "Current network: '$current'"

# Build network list in choose format
networks=""

# Add disconnect option if connected
if [[ -n "$current" ]]; then
    networks="Disconnect	Currently: $current	wifi.slash"
fi

# Add saved networks
while IFS= read -r ssid; do
    ssid="${ssid#"${ssid%%[![:space:]]*}"}"
    ssid="${ssid%"${ssid##*[![:space:]]}"}"
    [[ -z "$ssid" ]] && continue
    
    icon="wifi"
    subtitle="Saved"
    if [[ "$ssid" =~ (iPhone|iPad|Android|Pixel|Galaxy|Phone|Hotspot|Mobile) ]]; then
        icon="antenna.radiowaves.left.and.right"
        subtitle="Hotspot"
    fi
    
    if [[ "$ssid" == "$current" ]]; then
        subtitle="✓ Connected"
    fi
    
    if [[ -n "$networks" ]]; then
        networks="$networks"$'\n'"$ssid	$subtitle	$icon"
    else
        networks="$ssid	$subtitle	$icon"
    fi
done < <(networksetup -listpreferredwirelessnetworks "$INTERFACE" 2>/dev/null | tail -n +2)

# Add system settings option
networks="$networks"$'\n'"System WiFi Settings	Scan for new networks	gear"

log "Network list generated: $(echo "$networks" | wc -l) items"

# Show picker
selected=$(echo "$networks" | choose -p "WiFi Networks" -i "wifi")
exit_code=$?

log "Choose exit code: $exit_code"
log "Selected raw: '$selected'"

# Handle selection
if [[ -z "$selected" ]] || [[ $exit_code -ne 0 ]]; then
    log "No selection or cancelled"
    exit 0
fi

# Extract network name (first field)
ssid=$(echo "$selected" | cut -d$'\t' -f1)
log "Parsed SSID: '$ssid'"

case "$ssid" in
    "Disconnect")
        log "Action: Disconnect"
        # Turn WiFi off and on to disconnect
        networksetup -setairportpower "$INTERFACE" off
        sleep 0.5
        networksetup -setairportpower "$INTERFACE" on
        osascript -e 'display notification "Disconnected from WiFi" with title "WiFi"'
        ;;
    "System WiFi Settings")
        log "Action: Open Settings"
        open "x-apple.systempreferences:com.apple.wifi-settings-extension"
        ;;
    *)
        if [[ "$ssid" == "$current" ]]; then
            log "Action: Already connected"
            osascript -e "display notification \"Already connected to $ssid\" with title \"WiFi\""
        else
            log "Action: Connect to '$ssid'"
            osascript -e "display notification \"Connecting to $ssid...\" with title \"WiFi\""
            
            # Try to get saved password from keychain
            password=$(get_saved_password "$ssid")
            
            if [[ -n "$password" ]]; then
                log "Found saved password, connecting..."
                result=$(networksetup -setairportnetwork "$INTERFACE" "$ssid" "$password" 2>&1)
            else
                log "No saved password, trying without..."
                result=$(networksetup -setairportnetwork "$INTERFACE" "$ssid" 2>&1)
            fi
            
            log "Connection result: '$result'"
            
            # Check if connected
            sleep 1
            new_current=$(get_current_network)
            log "New current network: '$new_current'"
            
            if [[ "$new_current" == "$ssid" ]]; then
                osascript -e "display notification \"Connected to $ssid\" with title \"WiFi\""
            elif [[ -n "$result" ]]; then
                osascript -e "display notification \"$result\" with title \"WiFi\""
            else
                osascript -e "display notification \"Connection failed\" with title \"WiFi\""
            fi
        fi
        ;;
esac

log "=== WiFi picker finished ==="
