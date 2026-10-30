#!/usr/bin/env bash
set -euo pipefail

# Скрипт создания скриншота текущего сфокусированного монитора.
# Сохраняет изображение в ~/Pictures/Screenshots, копирует в буфер обмена (wl-copy)
# и отправляет уведомление. Вызывается по клавише Print.

# Каталог для сохранения скриншотов
out_dir="$HOME/Pictures/Screenshots"
mkdir -p "$out_dir"

file="$out_dir/$(date +%Y-%m-%d_%H-%M-%S).png"

# Определение имени активного (сфокусированного) монитора через hyprctl JSON
monitor="$(
  hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -n1
)"

if [[ -z "$monitor" ]]; then
  notify-send -a "Screenshot" "Screenshot" "No active monitor found"
  exit 1
fi

# Захват изображения через grim для указанного выхода (-o)
grim -o "$monitor" "$file"
# Копирование снимка в буфер обмена Wayland
wl-copy < "$file"
notify-send -a "Screenshot" "Screenshot" "Copied to clipboard\n$file"
