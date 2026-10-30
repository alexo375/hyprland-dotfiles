#!/usr/bin/env bash

# Скрипт управления громкостью динамиков и микрофона через WirePlumber (wpctl)
# с синхронными уведомлениями в Waybar Dynamic Island.

STEP=4          # Шаг изменения громкости в процентах (4%)
MAX_VOLUME=100  # Максимально допустимая громкость (100%)

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

# Обработка переключения микрофона (mic-mute)
if [ "$1" == "mic-mute" ]; then
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    IS_MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q "MUTED" && echo "true" || echo "false")
    if [ "$IS_MUTED" == "true" ]; then
        send_island_osd "󰍭" "Mic Muted" -1
    else
        send_island_osd "󰍬" "Mic Unmuted" -1
    fi
    exit 0
fi

# Получение текущих данных громкости и статуса заглушения (mute) динамиков через wpctl
VOLUME_DATA=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
CURRENT=$(echo "$VOLUME_DATA" | awk '{print $2 * 100}' | cut -d. -f1)
IS_MUTED=$(echo "$VOLUME_DATA" | grep -q "MUTED" && echo "true" || echo "false")

if [ "$1" == "up" ]; then
    [ "$IS_MUTED" == "true" ] && wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    NEW=$((CURRENT + STEP))
    [ $NEW -gt $MAX_VOLUME ] && NEW=$MAX_VOLUME
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${NEW}%"
elif [ "$1" == "down" ]; then
    NEW=$((CURRENT - STEP))
    [ $NEW -lt 0 ] && NEW=0
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${NEW}%"
elif [ "$1" == "mute" ]; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    VOLUME_DATA=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
    IS_MUTED=$(echo "$VOLUME_DATA" | grep -q "MUTED" && echo "true" || echo "false")
fi

NEW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100}' | cut -d. -f1)

if [ "$IS_MUTED" == "true" ]; then
    send_island_osd "󰝟" "Muted" -1
else
    send_island_osd "󰕾" "Volume: ${NEW}%" "$NEW"
fi
