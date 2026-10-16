#!/usr/bin/env bash

# Скрипт управления громкостью динамиков и микрофона через WirePlumber (wpctl)
# с синхронными всплывающими OSD-уведомлениями.

# Настройки шага изменения громкости и верхнего предела
STEP=4          # Шаг изменения громкости в процентах (4%)
MAX_VOLUME=100  # Максимально допустимая громкость (100%)

# Обработка переключения микрофона (mic-mute)
if [ "$1" == "mic-mute" ]; then
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    IS_MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q "MUTED" && echo "true" || echo "false")
    if [ "$IS_MUTED" == "true" ]; then
        notify-send -e -h string:x-canonical-private-synchronous:mic \
                    -u low -i microphone-sensitivity-muted-symbolic \
                    -t 1000 "Mic Muted"
    else
        notify-send -e -h string:x-canonical-private-synchronous:mic \
                    -u low -i microphone-sensitivity-high-symbolic \
                    -t 1000 "Mic Unmuted"
    fi
    exit 0
fi

# Получение текущих данных громкости и статуса заглушения (mute) динамиков через wpctl
VOLUME_DATA=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
CURRENT=$(echo "$VOLUME_DATA" | awk '{print $2 * 100}' | cut -d. -f1)
IS_MUTED=$(echo "$VOLUME_DATA" | grep -q "MUTED" && echo "true" || echo "false")

if [ "$1" == "up" ]; then
    # Автоматически снимаем mute при увеличении громкости
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

# Финальный опрос актуального значения громкости для отображения в OSD
NEW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2 * 100}' | cut -d. -f1)

# Формирование и отправка всплывающего OSD-уведомления
if [ "$IS_MUTED" == "true" ]; then
    notify-send -e -h string:x-canonical-private-synchronous:volume \
                -u low -i audio-volume-muted-symbolic \
                -t 1000 "Muted"
else
    notify-send -e -h string:x-canonical-private-synchronous:volume \
                -h int:value:"$NEW" \
                -u low -i audio-volume-high-symbolic \
                -t 1000 "Volume: ${NEW}%"
fi
