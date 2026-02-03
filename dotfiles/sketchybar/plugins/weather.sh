#!/bin/bash

# Weather plugin using Open-Meteo (free, no API key required)
# https://open-meteo.com/

JQ="/run/current-system/sw/bin/jq"
SKETCHYBAR="/opt/homebrew/bin/sketchybar"
CACHE_FILE="/tmp/sketchybar-weather-location.json"
CACHE_AGE=86400  # Cache location for 24 hours

# Get location from IP (cached to avoid rate limits)
get_location() {
    if [ -f "$CACHE_FILE" ]; then
        cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        if [ $((current_time - cache_time)) -lt $CACHE_AGE ]; then
            cat "$CACHE_FILE"
            return
        fi
    fi

    location=$(curl -s "http://ip-api.com/json/?fields=lat,lon,city" 2>/dev/null)
    if [ -n "$location" ] && echo "$location" | $JQ -e '.lat' >/dev/null 2>&1; then
        echo "$location" > "$CACHE_FILE"
        echo "$location"
    fi
}

LOCATION=$(get_location)
if [ -z "$LOCATION" ]; then
    $SKETCHYBAR --set $NAME icon="󰖐" label="--°"
    exit 0
fi

LAT=$(echo "$LOCATION" | $JQ -r '.lat')
LON=$(echo "$LOCATION" | $JQ -r '.lon')
CITY=$(echo "$LOCATION" | $JQ -r '.city // "Unknown"')

# Fetch comprehensive weather data from Open-Meteo
WEATHER=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&current=temperature_2m,apparent_temperature,weather_code,relative_humidity_2m,wind_speed_10m,wind_direction_10m,precipitation,cloud_cover,uv_index&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_sum,precipitation_probability_max,wind_speed_10m_max&hourly=temperature_2m,weather_code&timezone=auto&forecast_days=4" 2>/dev/null)

if [ -z "$WEATHER" ] || ! echo "$WEATHER" | $JQ -e '.current' >/dev/null 2>&1; then
    $SKETCHYBAR --set $NAME icon="󰖐" label="--°"
    exit 0
fi

# Parse current weather
TEMP=$(echo "$WEATHER" | $JQ -r '.current.temperature_2m // empty')
FEELS_LIKE=$(echo "$WEATHER" | $JQ -r '.current.apparent_temperature // empty')
WEATHER_CODE=$(echo "$WEATHER" | $JQ -r '.current.weather_code // 0')
HUMIDITY=$(echo "$WEATHER" | $JQ -r '.current.relative_humidity_2m // empty')
WIND_SPEED=$(echo "$WEATHER" | $JQ -r '.current.wind_speed_10m // empty')
WIND_DIR=$(echo "$WEATHER" | $JQ -r '.current.wind_direction_10m // empty')
PRECIPITATION=$(echo "$WEATHER" | $JQ -r '.current.precipitation // 0')
CLOUD_COVER=$(echo "$WEATHER" | $JQ -r '.current.cloud_cover // empty')
UV_INDEX=$(echo "$WEATHER" | $JQ -r '.current.uv_index // empty')

# Today's data
TODAY_MAX=$(echo "$WEATHER" | $JQ -r '.daily.temperature_2m_max[0] // empty')
TODAY_MIN=$(echo "$WEATHER" | $JQ -r '.daily.temperature_2m_min[0] // empty')
SUNRISE=$(echo "$WEATHER" | $JQ -r '.daily.sunrise[0] // empty')
SUNSET=$(echo "$WEATHER" | $JQ -r '.daily.sunset[0] // empty')
PRECIP_CHANCE=$(echo "$WEATHER" | $JQ -r '.daily.precipitation_probability_max[0] // 0')
PRECIP_SUM=$(echo "$WEATHER" | $JQ -r '.daily.precipitation_sum[0] // 0')

if [ -z "$TEMP" ]; then
    $SKETCHYBAR --set $NAME icon="󰖐" label="--°"
    exit 0
fi

# Map WMO weather code to icon and description
get_icon() {
    case $1 in
        0) echo "󰖙" ;;           # Clear sky
        1|2|3) echo "󰖐" ;;       # Partly cloudy
        45|48) echo "󰖑" ;;       # Fog
        51|53|55) echo "󰖗" ;;    # Drizzle
        56|57) echo "󰖗" ;;       # Freezing drizzle
        61|63|65) echo "󰖗" ;;    # Rain
        66|67) echo "󰖗" ;;       # Freezing rain
        71|73|75) echo "󰖘" ;;    # Snow
        77) echo "󰖘" ;;          # Snow grains
        80|81|82) echo "󰖗" ;;    # Rain showers
        85|86) echo "󰖘" ;;       # Snow showers
        95) echo "󰖓" ;;          # Thunderstorm
        96|99) echo "󰖓" ;;       # Thunderstorm with hail
        *) echo "󰖐" ;;
    esac
}

get_condition() {
    case $1 in
        0) echo "Clear" ;;
        1) echo "Mostly Clear" ;;
        2) echo "Partly Cloudy" ;;
        3) echo "Overcast" ;;
        45) echo "Foggy" ;;
        48) echo "Icy Fog" ;;
        51) echo "Light Drizzle" ;;
        53) echo "Drizzle" ;;
        55) echo "Heavy Drizzle" ;;
        56|57) echo "Freezing Drizzle" ;;
        61) echo "Light Rain" ;;
        63) echo "Rain" ;;
        65) echo "Heavy Rain" ;;
        66|67) echo "Freezing Rain" ;;
        71) echo "Light Snow" ;;
        73) echo "Snow" ;;
        75) echo "Heavy Snow" ;;
        77) echo "Snow Grains" ;;
        80) echo "Light Showers" ;;
        81) echo "Showers" ;;
        82) echo "Heavy Showers" ;;
        85) echo "Light Snow Showers" ;;
        86) echo "Snow Showers" ;;
        95) echo "Thunderstorm" ;;
        96|99) echo "Thunderstorm + Hail" ;;
        *) echo "Unknown" ;;
    esac
}

# Wind direction to compass
get_wind_dir() {
    local deg=$1
    if [ -z "$deg" ]; then echo ""; return; fi
    deg=$(printf "%.0f" "$deg")
    if [ $deg -ge 337 ] || [ $deg -lt 23 ]; then echo "N"
    elif [ $deg -ge 23 ] && [ $deg -lt 68 ]; then echo "NE"
    elif [ $deg -ge 68 ] && [ $deg -lt 113 ]; then echo "E"
    elif [ $deg -ge 113 ] && [ $deg -lt 158 ]; then echo "SE"
    elif [ $deg -ge 158 ] && [ $deg -lt 203 ]; then echo "S"
    elif [ $deg -ge 203 ] && [ $deg -lt 248 ]; then echo "SW"
    elif [ $deg -ge 248 ] && [ $deg -lt 293 ]; then echo "W"
    else echo "NW"
    fi
}

# UV index level
get_uv_level() {
    local uv=$(printf "%.0f" "$1")
    if [ $uv -le 2 ]; then echo "Low"
    elif [ $uv -le 5 ]; then echo "Moderate"
    elif [ $uv -le 7 ]; then echo "High"
    elif [ $uv -le 10 ]; then echo "Very High"
    else echo "Extreme"
    fi
}

ICON=$(get_icon $WEATHER_CODE)
CONDITION=$(get_condition $WEATHER_CODE)
TEMP_INT=$(printf "%.0f" "$TEMP")
FEELS_INT=$(printf "%.0f" "$FEELS_LIKE")
WIND_INT=$(printf "%.0f" "$WIND_SPEED")
WIND_COMPASS=$(get_wind_dir "$WIND_DIR")
UV_LEVEL=$(get_uv_level "$UV_INDEX")
UV_INT=$(printf "%.0f" "$UV_INDEX")
MAX_INT=$(printf "%.0f" "$TODAY_MAX")
MIN_INT=$(printf "%.0f" "$TODAY_MIN")
PRECIP_INT=$(printf "%.0f" "$PRECIP_CHANCE")

# Format sunrise/sunset times
SUNRISE_TIME=$(echo "$SUNRISE" | sed 's/.*T//' | cut -c1-5)
SUNSET_TIME=$(echo "$SUNSET" | sed 's/.*T//' | cut -c1-5)

# Update main bar item
$SKETCHYBAR --set $NAME icon="$ICON" label="${TEMP_INT}°"

# === POPUP ITEMS ===

# Row 1: Location & Current Condition
$SKETCHYBAR --set weather.location icon="󰍎" label="$CITY"
$SKETCHYBAR --set weather.condition icon="$ICON" label="$CONDITION"

# Row 2: Temperature details
$SKETCHYBAR --set weather.temp icon="󰔏" label="Now ${TEMP_INT}°  Feels ${FEELS_INT}°"
$SKETCHYBAR --set weather.highlow icon="󰞷" label="H ${MAX_INT}°  L ${MIN_INT}°"

# Row 3: Sun times
$SKETCHYBAR --set weather.sun icon="󰖨" label="↑${SUNRISE_TIME}  ↓${SUNSET_TIME}"

# Row 4: Wind & Humidity
$SKETCHYBAR --set weather.wind icon="󰖝" label="${WIND_INT} km/h ${WIND_COMPASS}"
$SKETCHYBAR --set weather.humidity icon="󰖎" label="${HUMIDITY}%"

# Row 5: UV & Precipitation
$SKETCHYBAR --set weather.uv icon="󰖨" label="UV ${UV_INT} (${UV_LEVEL})"
$SKETCHYBAR --set weather.precip icon="󰖗" label="${PRECIP_INT}% chance"

# Row 6: Hourly forecast (next 4 hours)
CURRENT_HOUR=$(date +%H)
for i in 0 1 2 3; do
    HOUR_INDEX=$((CURRENT_HOUR + i + 1))
    if [ $HOUR_INDEX -ge 24 ]; then
        HOUR_INDEX=$((HOUR_INDEX - 24))
    fi

    HOUR_TEMP=$(echo "$WEATHER" | $JQ -r ".hourly.temperature_2m[$HOUR_INDEX] // empty")
    HOUR_CODE=$(echo "$WEATHER" | $JQ -r ".hourly.weather_code[$HOUR_INDEX] // 0")

    if [ -n "$HOUR_TEMP" ]; then
        HOUR_ICON=$(get_icon $HOUR_CODE)
        HOUR_TEMP_INT=$(printf "%.0f" "$HOUR_TEMP")
        HOUR_LABEL=$(printf "%02d:00" $HOUR_INDEX)
        $SKETCHYBAR --set weather.hour.$i icon="$HOUR_ICON" label="${HOUR_LABEL} ${HOUR_TEMP_INT}°"
    fi
done

# Row 7+: 3-day forecast
for i in 1 2 3; do
    DAY_DATE=$(echo "$WEATHER" | $JQ -r ".daily.time[$i] // empty")
    DAY_CODE=$(echo "$WEATHER" | $JQ -r ".daily.weather_code[$i] // 0")
    DAY_MAX=$(echo "$WEATHER" | $JQ -r ".daily.temperature_2m_max[$i] // empty")
    DAY_MIN=$(echo "$WEATHER" | $JQ -r ".daily.temperature_2m_min[$i] // empty")

    if [ -n "$DAY_DATE" ] && [ -n "$DAY_MAX" ] && [ -n "$DAY_MIN" ]; then
        DAY_NAME=$(date -j -f "%Y-%m-%d" "$DAY_DATE" "+%a" 2>/dev/null || echo "Day$i")
        DAY_ICON=$(get_icon $DAY_CODE)
        DAY_MAX_INT=$(printf "%.0f" "$DAY_MAX")
        DAY_MIN_INT=$(printf "%.0f" "$DAY_MIN")
        $SKETCHYBAR --set weather.forecast.$i icon="$DAY_ICON" label="${DAY_NAME}  ${DAY_MAX_INT}°/${DAY_MIN_INT}°"
    fi
done
