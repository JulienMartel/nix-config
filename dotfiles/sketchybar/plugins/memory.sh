#!/bin/bash

# Get memory usage
MEMORY_USED=$(memory_pressure | grep "System-wide memory free percentage:" | awk '{print 100-$5}' | sed 's/%//')

# If memory_pressure doesn't work, fall back to vm_stat
if [ -z "$MEMORY_USED" ]; then
    TOTAL_MEM=$(sysctl -n hw.memsize)
    PAGE_SIZE=$(pagesize)

    VM_STAT=$(vm_stat)
    FREE_BLOCKS=$(echo "$VM_STAT" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    INACTIVE_BLOCKS=$(echo "$VM_STAT" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')

    FREE_MEM=$(echo "($FREE_BLOCKS + $INACTIVE_BLOCKS) * $PAGE_SIZE" | bc)
    USED_MEM=$(echo "$TOTAL_MEM - $FREE_MEM" | bc)
    MEMORY_USED=$(echo "scale=0; ($USED_MEM * 100) / $TOTAL_MEM" | bc)
fi

# Update the bar item
sketchybar --set $NAME \
    icon="" \
    label="${MEMORY_USED}%"
