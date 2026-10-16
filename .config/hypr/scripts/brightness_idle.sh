#!/usr/bin/env bash

# Скрипт автоматического затемнения экрана при бездействии (dim)
# и восстановления прежней яркости при активности (restore).
# Вызывается демоном hypridle.

# Настройки диапазона (синхронизированы с brightness_control.sh)
LIMIT_MAX_PC=50 # Рабочий максимум 50% от аппаратного предела
IDLE_FACTOR=10  # 10% от рабочей яркости во время простоя (глубокое затемнение)

# Временный файл для сохранения уровня яркости перед затемнением
BRIGHTNESS_FILE="/tmp/hypr_brightness_backup"

# Функция получения текущей аппаратной яркости
get_brightness() {
    brightnessctl get
}

case "$1" in
    dim)
        # Сохраняем текущую яркость только если она ещё не была сохранена
        if [ ! -f "$BRIGHTNESS_FILE" ]; then
            CURRENT_RAW=$(get_brightness)
            MAX_RAW=$(brightnessctl m)
            
            # Расчет рабочего максимума и целевого уровня затемнения при простое
            WORKING_MAX=$(( MAX_RAW * LIMIT_MAX_PC / 100 ))
            IDLE_RAW=$(( WORKING_MAX * IDLE_FACTOR / 100 ))

            # Понижаем яркость только если текущая яркость выше уровня простоя
            if [ "$CURRENT_RAW" -gt "$IDLE_RAW" ]; then
                echo "$CURRENT_RAW" > "$BRIGHTNESS_FILE"
                brightnessctl set "$IDLE_RAW"
            fi
        fi
        ;;
    restore)
        # Восстановление сохраненного уровня яркости при возобновлении активности
        if [ -f "$BRIGHTNESS_FILE" ]; then
            SAVED_BRIGHTNESS=$(cat "$BRIGHTNESS_FILE")
            brightnessctl set "$SAVED_BRIGHTNESS"
            rm "$BRIGHTNESS_FILE"
        fi
        ;;
    *)
        echo "Использование: $0 {dim|restore}"
        exit 1
        ;;
esac
