#!/usr/bin/env bash

# Скрипт плавного управления яркостью подсветки экрана через brightnessctl
# с отображением в Waybar Dynamic Island.

LIMIT_MIN_PC=0
LIMIT_MAX_PC=50
STEP_PC=2 # Шаг изменения яркости в процентах за одно нажатие клавиши

send_island_osd() {
    local icon="$1"
    local summary="$2"
    local val="${3:--1}"
    python3 -c '
import json, sys, time
data = {
    "app": "osd",
    "summary": sys.argv[1],
    "body": sys.argv[1],
    "value": int(sys.argv[2]) if sys.argv[2].lstrip("-").isdigit() else -1,
    "icon": sys.argv[3],
    "duration": 1.5,
    "timestamp": time.time()
}
with open("/dev/shm/waybar_notification.json", "w") as f:
    json.dump(data, f)
' "$summary" "$val" "$icon" 2>/dev/null || true
    touch /dev/shm/waybar_notification_active 2>/dev/null || true
    pkill -SIGUSR1 -f center_status.py 2>/dev/null || true
}

MAX_RAW=$(brightnessctl m)
CURRENT_RAW=$(brightnessctl g)

MIN_RAW=$(( MAX_RAW * LIMIT_MIN_PC / 100 ))
MAX_RAW_LIMIT=$(( MAX_RAW * LIMIT_MAX_PC / 100 ))
STEP_RAW=$(( MAX_RAW * STEP_PC / 100 ))

if [ "$1" == "up" ]; then
    NEW_RAW=$(( CURRENT_RAW + STEP_RAW ))
elif [ "$1" == "down" ]; then
    NEW_RAW=$(( CURRENT_RAW - STEP_RAW ))
else
    exit 0
fi

[ "$NEW_RAW" -gt "$MAX_RAW_LIMIT" ] && NEW_RAW=$MAX_RAW_LIMIT
[ "$NEW_RAW" -lt "$MIN_RAW" ] && NEW_RAW=$MIN_RAW

brightnessctl set "$NEW_RAW"

RANGE_RAW=$(( MAX_RAW_LIMIT - MIN_RAW ))
if [ "$RANGE_RAW" -le 0 ]; then
    RELATIVE=100
else
    RELATIVE=$(( (NEW_RAW - MIN_RAW) * 100 / RANGE_RAW ))
fi

send_island_osd "󰃠" "Brightness: ${RELATIVE}%" "$RELATIVE"
