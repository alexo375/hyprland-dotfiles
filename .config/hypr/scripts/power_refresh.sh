#!/usr/bin/env bash
set -euo pipefail

# Скрипт динамического переключения частоты обновления экрана (60Hz / 90Hz):
# Используется в Waybar и меню производительности Rofi для экономии батареи ноутбука.
# Поддерживает режимы:
#   --status       (вывод текущей частоты с иконкой для статус-бара)
#   --toggle       (переключение 60Hz <-> 90Hz)
#   --set <hz>     (установка конкретной частоты)

LOW_HZ="${LOW_HZ:-60}"
HIGH_HZ="${HIGH_HZ:-90}"

# Определение имени активного монитора (по умолчанию eDP-1 ноутбука)
get_monitor() {
    hyprctl monitors | grep "Monitor " | awk '{print $2}' | head -n 1
}

# Извлечение параметров текущего монитора: разрешение, частота, позиция и масштаб (scale)
get_monitor_state() {
    local monitor="$1"
    hyprctl monitors | awk -v mon="$monitor" '
        $1=="Monitor" {
            if (in_mon && $2!=mon) { exit }
            in_mon=($2==mon)
            next
        }
        in_mon && $1 ~ /@/ {
            split($1, a, "@")
            res=a[1]
            rate=a[2]
            pos=$3
            next
        }
        in_mon && $1=="scale:" { scale=$2 }
        END { print res, rate, pos, scale }
    '
}

# Применение новой частоты обновления через команду 'hyprctl keyword monitor'
set_refresh() {
    local rate="$1"
    local monitor
    monitor="$(get_monitor)"

    if [ -z "${monitor:-}" ]; then
        monitor="eDP-1"
    fi

    local res current_rate pos scale
    read -r res current_rate pos scale < <(get_monitor_state "$monitor")

    res="${res:-2520x1680}"
    pos="${pos:-0x0}"
    scale="${scale:-1.5}"

    hyprctl keyword monitor "$monitor,${res}@${rate},${pos},${scale}" >/dev/null
}

# Получение текущей частоты в виде целого числа
get_current_rate_int() {
    local monitor="$1"
    local _res rate _pos _scale
    read -r _res rate _pos _scale < <(get_monitor_state "$monitor")
    rate="${rate:-0}"
    rate="${rate%%.*}"
    printf "%s\n" "${rate:-0}"
}

# Печать статуса для Waybar
print_status() {
    local monitor rate
    monitor="$(get_monitor)"
    monitor="${monitor:-eDP-1}"
    rate="$(get_current_rate_int "$monitor")"

    if [ "$rate" -ge "$HIGH_HZ" ]; then
        printf "󰄵 %sHz\n" "$rate"
    else
        printf "󰄴 %sHz\n" "$rate"
    fi
}

# Циклическое переключение частоты
toggle_refresh() {
    local monitor rate
    monitor="$(get_monitor)"
    monitor="${monitor:-eDP-1}"
    rate="$(get_current_rate_int "$monitor")"

    if [ "$rate" -ge "$HIGH_HZ" ]; then
        set_refresh "$LOW_HZ"
    else
        set_refresh "$HIGH_HZ"
    fi
}

case "${1:-}" in
    --status|"")
        print_status
        ;;
    --toggle)
        toggle_refresh
        ;;
    --set)
        shift
        [ -n "${1:-}" ] || exit 2
        set_refresh "$1"
        ;;
    *)
        echo "Использование: $0 [--status|--toggle|--set <hz>]" >&2
        exit 1
        ;;
esac
