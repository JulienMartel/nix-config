#!/bin/bash

# Brew Services Manager
# Lists all brew services with status and allows start/stop/restart

# Get list of services with status
get_services() {
    brew services list 2>/dev/null | tail -n +2 | while read -r line; do
        name=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')

        [[ -z "$name" ]] && continue

        # Determine icon and actions based on status
        case "$status" in
            started|running)
                icon="checkmark.circle.fill"
                subtitle="Running"
                # Running: default=Stop, cmd=Restart, opt=Open logs
                actions="Stop|cmd:Restart"
                ;;
            stopped|none|"")
                icon="circle"
                subtitle="Stopped"
                # Stopped: default=Start, cmd=Remove
                actions="Start|cmd:Uninstall"
                ;;
            error)
                icon="exclamationmark.circle.fill"
                subtitle="Error"
                actions="Restart|cmd:Stop|opt:View Logs"
                ;;
            *)
                icon="questionmark.circle"
                subtitle="$status"
                actions="Start|cmd:Stop|opt:Restart"
                ;;
        esac

        echo -e "${name}\t${subtitle}\t${icon}\t${actions}"
    done
}

# Show the picker
services=$(get_services)

if [[ -z "$services" ]]; then
    osascript -e 'display notification "No brew services found" with title "Brew Services"'
    exit 0
fi

# Run choose and capture output (format: action\traw_line)
result=$(echo "$services" | choose -p "Brew Services" -i "shippingbox")

if [[ -z "$result" ]]; then
    exit 0
fi

# Parse the result
action=$(echo "$result" | cut -f1)
service_line=$(echo "$result" | cut -f2-)
service_name=$(echo "$service_line" | cut -f1)
current_status=$(echo "$service_line" | cut -f2)

# Execute the action
case "$action" in
    enter)
        # Default action based on status
        if [[ "$current_status" == "Running" ]]; then
            brew services stop "$service_name"
            osascript -e "display notification \"Stopped $service_name\" with title \"Brew Services\""
        else
            brew services start "$service_name"
            osascript -e "display notification \"Started $service_name\" with title \"Brew Services\""
        fi
        ;;
    cmd)
        # Cmd action: Restart if running, Uninstall if stopped
        if [[ "$current_status" == "Running" ]]; then
            brew services restart "$service_name"
            osascript -e "display notification \"Restarted $service_name\" with title \"Brew Services\""
        else
            # Confirm before uninstalling
            response=$(osascript -e "display dialog \"Uninstall $service_name?\" buttons {\"Cancel\", \"Uninstall\"} default button \"Cancel\"" 2>/dev/null)
            if [[ "$response" == *"Uninstall"* ]]; then
                brew uninstall "$service_name"
                osascript -e "display notification \"Uninstalled $service_name\" with title \"Brew Services\""
            fi
        fi
        ;;
    opt)
        # Option action: View logs
        log_path="/opt/homebrew/var/log/${service_name}"
        if [[ -d "$log_path" ]]; then
            open "$log_path"
        else
            # Try common log locations
            log_file=$(find /opt/homebrew/var/log -name "*${service_name}*" -type f 2>/dev/null | head -1)
            if [[ -n "$log_file" ]]; then
                open -a "Console" "$log_file"
            else
                osascript -e "display notification \"No logs found for $service_name\" with title \"Brew Services\""
            fi
        fi
        ;;
    ctrl)
        # Ctrl action: Show info
        brew info "$service_name"
        ;;
esac
