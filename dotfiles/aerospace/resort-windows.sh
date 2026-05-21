#!/bin/bash
# Re-apply workspace assignments to every existing window.
# Mirrors the on-window-detected rules in aerospace.toml, which only fire on
# first detection — after macOS wake events windows often pile up on the
# current workspace and need re-sorting.

set -u

focused=$(aerospace list-workspaces --focused 2>/dev/null || true)

# Snapshot the window list first — piping into the loop would let the
# `aerospace move-node-to-workspace` calls inside consume stdin and starve
# the read.
windows=$(aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}|%{window-title}' 2>/dev/null)

while IFS='|' read -r id bundle title; do
    id=$(echo "$id" | tr -d ' ')
    bundle=$(echo "$bundle" | sed 's/^ *//;s/ *$//')
    title=$(echo "$title" | sed 's/^ *//;s/ *$//')

    [ -z "$id" ] && continue

    target=""
    case "$bundle" in
        com.todesktop.230313mzl4w4u92) target="C" ;;
        com.google.Chrome.app.caidcmannjgahlnbpmidmiecjcoiiigg) target="G" ;;
        com.mitchellh.ghostty)
            case "$title" in
                quick-terminal*) continue ;;
                *) target="T" ;;
            esac
            ;;
        com.apple.Notes|com.culturedcode.ThingsMac|md.obsidian) target="N" ;;
        com.linear) target="L" ;;
        com.tinyspeck.slackmacgap) target="S" ;;
        app.zen-browser.zen) target="B" ;;
        com.figma.Desktop) target="F" ;;
        com.apple.Music) target="M" ;;
        com.swather.app) target="H" ;;
        *) continue ;;
    esac

    # </dev/null is critical: aerospace reads stdin and would otherwise
    # drain the herestring, ending the loop after one iteration.
    aerospace move-node-to-workspace --window-id "$id" "$target" </dev/null >/dev/null 2>&1 || true
done <<< "$windows"

if [ -n "$focused" ]; then
    aerospace workspace "$focused" >/dev/null 2>&1 || true
fi
