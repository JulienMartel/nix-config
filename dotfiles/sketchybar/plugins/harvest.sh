#!/bin/bash

source "$HOME/.config/sketchybar/harvest_secrets.sh"

# API Configuration
HARVEST_API_URL="https://api.harvestapp.com/v2"

# Add timestamp to bust any caching
TIMESTAMP=$(date +%s)

HEADERS=(
  -H "Authorization: Bearer $HARVEST_ACCESS_TOKEN"
  -H "Harvest-Account-ID: $HARVEST_ACCOUNT_ID"
  -H "User-Agent: Sketchybar Plugin"
  -H "Content-Type: application/json"
  -H "Cache-Control: no-cache, no-store, must-revalidate"
  -H "Pragma: no-cache"
)

# Colors (Catppuccin Mocha)
PEACH=0xfffab387
SURFACE0=0xff313244
BASE=0xff1e1e2e
TEXT=0xffcdd6f4

# Helper to format duration
format_duration() {
  local hours=$1
  local total_mins=$(printf "%.0f" $(echo "$hours * 60" | bc))
  local h=$((total_mins / 60))
  local m=$((total_mins % 60))
  if [ $h -gt 0 ]; then
    echo "${h}h${m}m"
  else
    echo "${m}m"
  fi
}

# Handle click events
if [ "$SENDER" = "mouse.clicked" ]; then
  # Right-click or modifier: Open Harvest app
  if [ "$BUTTON" = "right" ] || [ "$MODIFIER" = "shift" ] || [ "$MODIFIER" = "cmd" ]; then
    open -a "Harvest"
    exit 0
  fi

  # Left-click: Toggle timer
  CURRENT_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?is_running=true&_=$TIMESTAMP")
  IS_RUNNING=$(echo "$CURRENT_ENTRY" | jq -r '.time_entries | length')

  if [ "$IS_RUNNING" -gt "0" ]; then
    # STOP the running timer
    ENTRY_ID=$(echo "$CURRENT_ENTRY" | jq -r '.time_entries[0].id')
    PROJECT_NAME=$(echo "$CURRENT_ENTRY" | jq -r '.time_entries[0].client.name // .time_entries[0].project.name // "Timer"')

    # Optimistic UI update
    sketchybar --set $NAME \
      icon.color=$TEXT \
      label.color=$TEXT \
      background.color=$SURFACE0 \
      label="$PROJECT_NAME"

    # Stop the timer
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "${HEADERS[@]}" "$HARVEST_API_URL/time_entries/$ENTRY_ID/stop")

    if [ "$HTTP_CODE" -ne 200 ]; then
      osascript -e 'display notification "Failed to stop timer" with title "Harvest"'
      sketchybar --trigger harvest_update
    fi

  else
    # START/RESTART the last timer
    LAST_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?per_page=1&_=$TIMESTAMP")
    ENTRY_ID=$(echo "$LAST_ENTRY" | jq -r '.time_entries[0].id')
    PROJECT_NAME=$(echo "$LAST_ENTRY" | jq -r '.time_entries[0].client.name // .time_entries[0].project.name // "Timer"')

    if [ "$ENTRY_ID" != "null" ] && [ -n "$ENTRY_ID" ]; then
      # Optimistic UI update
      sketchybar --set $NAME \
        icon.color=$BASE \
        label.color=$BASE \
        background.color=$PEACH \
        label="$PROJECT_NAME"

      # Restart the timer
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "${HEADERS[@]}" "$HARVEST_API_URL/time_entries/$ENTRY_ID/restart")

      if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ]; then
        osascript -e 'display notification "Failed to restart timer" with title "Harvest"'
        sketchybar --trigger harvest_update
      fi
    else
      osascript -e 'display notification "No previous timer to restart" with title "Harvest"'
    fi
  fi

  exit 0
fi

# Regular update: Always fetch fresh data from server
RUNNING_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?is_running=true&_=$TIMESTAMP")
RUNNING_COUNT=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries | length // 0')

if [ "$RUNNING_COUNT" -gt "0" ]; then
  # Timer is RUNNING
  CLIENT=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries[0].client.name // empty')
  PROJECT=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries[0].project.name // empty')
  TASK=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries[0].task.name // empty')
  NOTES=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries[0].notes // empty')
  HOURS=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries[0].hours // 0')

  # Build label: prefer client name, fall back to project, add duration
  if [ -n "$CLIENT" ] && [ "$CLIENT" != "null" ]; then
    LABEL="$CLIENT"
  elif [ -n "$PROJECT" ] && [ "$PROJECT" != "null" ]; then
    LABEL="$PROJECT"
  else
    LABEL="Running"
  fi

  # Add duration if available
  if [ -n "$HOURS" ] && [ "$HOURS" != "null" ] && [ "$HOURS" != "0" ]; then
    DURATION=$(format_duration "$HOURS")
    LABEL="$LABEL · $DURATION"
  fi

  sketchybar --set $NAME \
    icon="󰔟" \
    icon.color=$BASE \
    label.color=$BASE \
    background.color=$PEACH \
    label="$LABEL" \
    drawing=on
else
  # Timer is STOPPED - show last entry for quick resume
  LATEST_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?per_page=1&_=$TIMESTAMP")
  CLIENT=$(echo "$LATEST_ENTRY" | jq -r '.time_entries[0].client.name // empty')
  PROJECT=$(echo "$LATEST_ENTRY" | jq -r '.time_entries[0].project.name // empty')

  if [ -n "$CLIENT" ] && [ "$CLIENT" != "null" ]; then
    LABEL="$CLIENT"
  elif [ -n "$PROJECT" ] && [ "$PROJECT" != "null" ]; then
    LABEL="$PROJECT"
  else
    LABEL="Start Timer"
  fi

  sketchybar --set $NAME \
    icon="󰔟" \
    icon.color=$TEXT \
    label.color=$TEXT \
    background.color=$SURFACE0 \
    label="$LABEL" \
    drawing=on
fi
