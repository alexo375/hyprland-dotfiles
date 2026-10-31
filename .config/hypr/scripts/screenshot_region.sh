#!/usr/bin/env bash
set -euo pipefail

# Скрипт создания скриншота выделенной области экрана (через slurp и grim)
# с поддержкой повтора захвата последней области (--repeat / --last).
# Сохраняет изображение в ~/Pictures/Screenshots и копирует в буфер обмена.

out_dir="$HOME/Pictures/Screenshots"
mkdir -p "$out_dir"

# Файл сохранения геометрии последнего выделения
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
state_file="$state_dir/last_screenshot_region"
mkdir -p "$state_dir"

mode="${1:-select}"

# Функция захвата указанной геометрии
capture() {
  local geometry="$1"
  local file
  file="$out_dir/$(date +%Y-%m-%d_%H-%M-%S).png"

  # Небольшая пауза, чтобы оверлей выделения slurp успел исчезнуть с экрана
  sleep 0.15
  grim -g "$geometry" "$file"
  wl-copy < "$file"
  printf '%s\n' "$geometry" > "$state_file"
  notify-send -a "Screenshot" "Screenshot" $'Copied to clipboard\n'"$file"
}

case "$mode" in
  select)
    # Интерактивное выделение области с полупрозрачной рамкой темы
    geometry="$(slurp -w 2 -b 00000044 -c 7aa2f7ff -s 7aa2f733 2>/dev/null || true)"
    [[ -z "$geometry" ]] && exit 0
    capture "$geometry"
    ;;
  --last|--repeat)
    # Повторный снимок ранее сохраненной области без интерактивного запроса
    if [[ ! -s "$state_file" ]]; then
      notify-send -a "Screenshot" "Screenshot" "No previous region found"
      exit 1
    fi
    geometry="$(<"$state_file")"
    [[ -z "$geometry" ]] && exit 1
    capture "$geometry"
    ;;
  *)
    echo "Использование: $(basename "$0") [select|--last|--repeat]" >&2
    exit 2
    ;;
esac
