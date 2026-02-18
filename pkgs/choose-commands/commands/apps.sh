#!/bin/bash

# Applications Launcher
# Lists installed macOS apps with their actual icons

get_apps() {
    # Search only where real user-facing apps live (same dirs as Raycast/Spotlight)
    # -prune on *.app prevents descending into bundles (no nested helpers)
    find /Applications /System/Applications ~/Applications \
        -name "*.app" -type d -prune 2>/dev/null | \
        while IFS= read -r app_path; do
            app_name=$(basename "$app_path" .app)
            [[ -z "$app_name" ]] && continue
            echo -e "${app_name}\tApplications\tapp:${app_path}\tLaunch|cmd:Show in Finder"
        done | sort -f
}

# Show the picker
apps=$(get_apps)

if [[ -z "$apps" ]]; then
    osascript -e 'display notification "No applications found" with title "Applications"'
    exit 0
fi

result=$(echo "$apps" | choose -p "Applications" -i "square.grid.2x2")

if [[ -z "$result" ]]; then
    exit 0
fi

# Parse the result
action=$(echo "$result" | cut -f1)
app_line=$(echo "$result" | cut -f2-)
app_name=$(echo "$app_line" | cut -f1)
app_path=$(echo "$app_line" | cut -f3)
# Strip the app: prefix to get the real path
app_path="${app_path#app:}"

case "$action" in
    enter)
        open -a "$app_path"
        ;;
    cmd)
        open -R "$app_path"
        ;;
esac
