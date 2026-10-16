#!/usr/bin/env bash

# Скрипт плавного управления яркостью подсветки экрана через brightnessctl
# с отображением всплывающего OSD-индикатора через notify-send.

# Ограничения рабочего диапазона яркости в процентах от максимума контроллера:
# LIMIT_MAX_PC=50 задает безопасный максимум комфортной яркости (защита глаз)
LIMIT_MIN_PC=0
LIMIT_MAX_PC=50
STEP_PC=2 # Шаг изменения яркости в процентах за одно нажатие клавиши

# Получение сырых значений от аппаратного контроллера brightnessctl
MAX_RAW=$(brightnessctl m)
CURRENT_RAW=$(brightnessctl g)

# Перевод относительных процентов в сырые аппаратные тики
MIN_RAW=$(( MAX_RAW * LIMIT_MIN_PC / 100 ))
MAX_RAW_LIMIT=$(( MAX_RAW * LIMIT_MAX_PC / 100 ))
STEP_RAW=$(( MAX_RAW * STEP_PC / 100 ))

# Расчет нового значения яркости в зависимости от переданного аргумента (up / down)
if [ "$1" == "up" ]; then
    NEW_RAW=$(( CURRENT_RAW + STEP_RAW ))
elif [ "$1" == "down" ]; then
    NEW_RAW=$(( CURRENT_RAW - STEP_RAW ))
else
    exit 0
fi

# Ограничение целевого значения допустимыми границами [MIN_RAW, MAX_RAW_LIMIT]
[ "$NEW_RAW" -gt "$MAX_RAW_LIMIT" ] && NEW_RAW=$MAX_RAW_LIMIT
[ "$NEW_RAW" -lt "$MIN_RAW" ] && NEW_RAW=$MIN_RAW

# Применение нового значения к аппаратному устройству
brightnessctl set "$NEW_RAW"

# Расчет процента заполнения полосы OSD относительно нашего пользовательского диапазона
RANGE_RAW=$(( MAX_RAW_LIMIT - MIN_RAW ))
if [ "$RANGE_RAW" -le 0 ]; then
    RELATIVE=100
else
    RELATIVE=$(( (NEW_RAW - MIN_RAW) * 100 / RANGE_RAW ))
fi

# Отправка синхронного всплывающего уведомления в swaync/dunst с полосой прогресса
notify-send -e -h string:x-canonical-private-synchronous:brightness \
            -h int:value:"$RELATIVE" \
            -u low \
            -i display-brightness-symbolic \
            -t 1000 "Brightness: $RELATIVE%"
