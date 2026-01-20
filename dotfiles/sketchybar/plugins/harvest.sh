#!/bin/bash

source "$HOME/.config/sketchybar/harvest_secrets.sh"

# API Configuration
HARVEST_API_URL="https://api.harvestapp.com/v2"
HEADERS=(
  -H "Authorization: Bearer $HARVEST_ACCESS_TOKEN"
  -H "Harvest-Account-ID: $HARVEST_ACCOUNT_ID"
  -H "User-Agent: Sketchybar Plugin"
  -H "Content-Type: application/json"
)

# Colors
PEACH=0xfffab387
SURFACE0=0xff313244
BASE=0xff1e1e2e
TEXT=0xffcdd6f4

if [ "$SENDER" = "mouse.clicked" ]; then
  # Handle "Open App" action (Right Click or Modifier Key)
  if [ "$BUTTON" = "right" ] || [ "$MODIFIER" = "shift" ] || [ "$MODIFIER" = "cmd" ]; then
    open -a "Harvest"
    exit 0
  fi

  # Check for running timer to decide action
  # We fetch current state to get IDs, but apply UI updates optimistically
  
  CURRENT_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?is_running=true")
  IS_RUNNING=$(echo "$CURRENT_ENTRY" | jq -r '.time_entries | length')

  if [ "$IS_RUNNING" -gt "0" ]; then
    # STOPPING
    
    # Get Project Name from current entry to preserve it in label
    PROJECT_NAME=$(echo "$CURRENT_ENTRY" | jq -r '.time_entries[0].client.name')

    # 1. Optimistic UI Update: Set to IDLE but keep Project Name
    sketchybar --set $NAME \
      icon.color=$TEXT \
      label.color=$TEXT \
      background.color=$SURFACE0 \
      label="$PROJECT_NAME"

    # 2. Perform API Action
    ENTRY_ID=$(echo "$CURRENT_ENTRY" | jq -r '.time_entries[0].id')
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "${HEADERS[@]}" "$HARVEST_API_URL/time_entries/$ENTRY_ID/stop")
    
    # 3. Handle Failure
    if [ "$HTTP_CODE" -ne 200 ]; then
       osascript -e 'display notification "Failed to stop timer" with title "Harvest Plugin"'
       sketchybar --trigger harvest_update # Revert UI
    fi

  else
    # STARTING
    
    # 1. Fetch Last Entry (needed for ID and Project Name)
    LAST_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?per_page=1")
    ENTRY_ID=$(echo "$LAST_ENTRY" | jq -r '.time_entries[0].id')
    PROJECT_NAME=$(echo "$LAST_ENTRY" | jq -r '.time_entries[0].client.name')
    
    if [ "$ENTRY_ID" != "null" ]; then
       # 2. Optimistic UI Update: Set to RUNNING
       sketchybar --set $NAME \
         icon.color=$BASE \
         label.color=$BASE \
         background.color=$PEACH \
         label="$PROJECT_NAME"

       # 3. Perform API Action
       HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH "${HEADERS[@]}" "$HARVEST_API_URL/time_entries/$ENTRY_ID/restart")
       
       # 4. Handle Failure
       if [ "$HTTP_CODE" -ne 200 ] && [ "$HTTP_CODE" -ne 201 ]; then
           osascript -e 'display notification "Failed to restart timer" with title "Harvest Plugin"'
           sketchybar --trigger harvest_update # Revert UI
       fi
    else
        # No previous entry to restart
        osascript -e 'display notification "No previous timer to restart" with title "Harvest Plugin"'
    fi
  fi
  
  exit 0
fi

# Fetch current state (Regular Update)
# 1. First check for ANY running timer (most important)
RUNNING_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?is_running=true")
RUNNING_COUNT=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries | length')

if [ "$RUNNING_COUNT" -gt "0" ]; then
  PROJECT=$(echo "$RUNNING_ENTRY" | jq -r '.time_entries[0].client.name')
  
  sketchybar --set $NAME \
    icon="󰔟" \
    icon.color=$BASE \
    label.color=$BASE \
    background.color=$PEACH \
    label="$PROJECT" \
    drawing=on
else
  # 2. If no timer is running, get the latest used timer for the "Resume" label
  LATEST_ENTRY=$(curl -s "${HEADERS[@]}" "$HARVEST_API_URL/time_entries?per_page=1")
  PROJECT=$(echo "$LATEST_ENTRY" | jq -r '.time_entries[0].client.name')

  # Check if we have a project name to display
  if [ "$PROJECT" != "null" ] && [ -n "$PROJECT" ]; then
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
