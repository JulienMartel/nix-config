#!/bin/bash

# Weather plugin using WeatherAPI.com
API_KEY="b45b54a6ad0c4f45a8f152745262601"
JQ="/run/current-system/sw/bin/jq"
SKETCHYBAR="/opt/homebrew/bin/sketchybar"

# Fetch weather (auto-detects location from IP)
WEATHER=$(curl -s "https://api.weatherapi.com/v1/forecast.json?key=${API_KEY}&q=auto:ip&days=4" 2>/dev/null)

if [ -z "$WEATHER" ]; then
    $SKETCHYBAR --set $NAME icon="󰖐" label="--°"
    exit 0
fi

# Parse current weather
TEMP=$(echo "$WEATHER" | $JQ -r '.current.temp_c // empty')
CONDITION=$(echo "$WEATHER" | $JQ -r '.current.condition.code // 1000')

if [ -z "$TEMP" ]; then
    $SKETCHYBAR --set $NAME icon="󰖐" label="--°"
    exit 0
fi

# Map condition code to icon
get_icon() {
    case $1 in
        1000) echo "󰖙" ;;         # Sunny/Clear
        1003) echo "󰖐" ;;         # Partly cloudy
        1006|1009) echo "󰖐" ;;    # Cloudy/Overcast
        1030|1135|1147) echo "󰖑" ;; # Mist/Fog
        1063|1180|1183|1186|1189|1192|1195|1240|1243|1246) echo "󰖗" ;; # Rain
        1066|1114|1210|1213|1216|1219|1222|1225|1255|1258) echo "󰖘" ;; # Snow
        1069|1072|1150|1153|1168|1171|1198|1201|1204|1207|1249|1252) echo "󰖗" ;; # Sleet/Drizzle
        1087|1273|1276|1279|1282) echo "󰖓" ;; # Thunder
        *) echo "󰖐" ;;
    esac
}

ICON=$(get_icon $CONDITION)
TEMP_INT=$(printf "%.0f" "$TEMP")

$SKETCHYBAR --set $NAME icon="$ICON" label="${TEMP_INT}°"

# Update forecast popup items
for i in 1 2 3; do
    DAY_NAME=$(echo "$WEATHER" | $JQ -r ".forecast.forecastday[$i].date" | xargs -I{} date -j -f "%Y-%m-%d" "{}" "+%a" 2>/dev/null)
    DAY_CODE=$(echo "$WEATHER" | $JQ -r ".forecast.forecastday[$i].day.condition.code // 1000")
    DAY_MAX=$(echo "$WEATHER" | $JQ -r ".forecast.forecastday[$i].day.maxtemp_c // empty")
    DAY_MIN=$(echo "$WEATHER" | $JQ -r ".forecast.forecastday[$i].day.mintemp_c // empty")

    if [ -n "$DAY_MAX" ] && [ -n "$DAY_MIN" ]; then
        DAY_ICON=$(get_icon $DAY_CODE)
        MAX_INT=$(printf "%.0f" "$DAY_MAX")
        MIN_INT=$(printf "%.0f" "$DAY_MIN")
        $SKETCHYBAR --set weather.forecast.$i icon="$DAY_ICON" label="${DAY_NAME}  ${MAX_INT}°/${MIN_INT}°"
    fi
done
