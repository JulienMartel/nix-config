#!/bin/bash

# Calendar plugin using icalBuddy
ICALBUDDY="/opt/homebrew/bin/icalBuddy"
SKETCHYBAR="/opt/homebrew/bin/sketchybar"

# Get next timed event (exclude all-day events)
# -n: limit to next event
# -nc: no calendar names
# -nrd: no relative dates
# -ea: exclude all-day events
# -df: date format
# -tf: time format
EVENT=$($ICALBUDDY -n -nc -nrd -ea -df "%Y-%m-%d" -tf "%H:%M" -iep "title,datetime" -b "" -ps "| @ |" eventsToday+7 2>/dev/null | head -1)

if [ -z "$EVENT" ] || [ "$EVENT" = "" ]; then
    $SKETCHYBAR --set $NAME label="No events"
    # Clear popup items
    for i in 1 2 3 4 5; do
        $SKETCHYBAR --set calendar.event.$i label="" icon="" drawing=off 2>/dev/null
    done
    exit 0
fi

# Parse title and datetime
# Format: "Title @ 2026-01-28 at 09:00 - 09:20"
TITLE=$(echo "$EVENT" | sed 's/ @ [0-9].*//')
DATETIME=$(echo "$EVENT" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} at [0-9]{2}:[0-9]{2}' | sed 's/ at / /')

if [ -z "$DATETIME" ]; then
    $SKETCHYBAR --set $NAME label="No events"
    exit 0
fi

# Calculate time until event
EVENT_EPOCH=$(date -j -f "%Y-%m-%d %H:%M" "$DATETIME" "+%s" 2>/dev/null)
NOW_EPOCH=$(date "+%s")
DIFF=$((EVENT_EPOCH - NOW_EPOCH))

if [ $DIFF -lt 0 ] || [ $DIFF -gt 86400 ]; then
    # Event is in progress, passed, or more than 24h away
    $SKETCHYBAR --set $NAME label="No events"
    exit 0
fi

# Calculate hours and minutes
HOURS=$((DIFF / 3600))
MINUTES=$(((DIFF % 3600) / 60))

# Format time string
if [ $HOURS -gt 0 ]; then
    if [ $MINUTES -gt 0 ]; then
        TIME_STR="${HOURS}h${MINUTES}m"
    else
        TIME_STR="${HOURS}h"
    fi
else
    TIME_STR="${MINUTES}m"
fi

# Truncate title to 15 chars
if [ ${#TITLE} -gt 15 ]; then
    TITLE="${TITLE:0:12}..."
fi

$SKETCHYBAR --set $NAME label="$TITLE in $TIME_STR"

# Update popup with next 5 events
EVENTS=$($ICALBUDDY -n 5 -nc -nrd -ea -df "%Y-%m-%d" -tf "%H:%M" -iep "title,datetime" -b "" -ps "| @ |" eventsToday+7 2>/dev/null)

i=1
while IFS= read -r line && [ $i -le 5 ]; do
    if [ -n "$line" ]; then
        POPUP_TITLE=$(echo "$line" | sed 's/ @ [0-9].*//')
        POPUP_TIME=$(echo "$line" | grep -oE '[0-9]{2}:[0-9]{2}' | head -1)

        # Truncate popup title
        if [ ${#POPUP_TITLE} -gt 25 ]; then
            POPUP_TITLE="${POPUP_TITLE:0:22}..."
        fi

        $SKETCHYBAR --set calendar.event.$i icon="󰃭" label="$POPUP_TIME $POPUP_TITLE" drawing=on 2>/dev/null
        ((i++))
    fi
done <<< "$EVENTS"

# Hide unused popup items
while [ $i -le 5 ]; do
    $SKETCHYBAR --set calendar.event.$i label="" icon="" drawing=off 2>/dev/null
    ((i++))
done
