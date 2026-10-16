#!/usr/bin/env bash
set -euo pipefail

# Скрипт всплывающего (scratchpad / dropdown) окна для терминальных TUI-утилит
# (например, nmtui для Wi-Fi, bluetui для Bluetooth, pulsemixer для звука).
# Поведение:
#   1. Если окно не запущено -> запускает kitty с нужным классом по центру экрана в плавающем режиме.
#   2. Если окно уже открыто и активно -> закрывает его.
#   3. Если окно открыто на другом воркспейсе / не в фокусе -> фокусирует его.

if [[ $# -lt 1 ]]; then
  echo "Использование: $0 <app>" >&2
  exit 1
fi

app="$1"
class="tui-toggle-${app}"
title="TUI_TOGGLE_${app^^}"

# Поиск адреса существующего окна среди клиентов Hyprland по WM_CLASS
addr="$(hyprctl -j clients | jq -r --arg class "$class" '
  map(select(.class == $class or .initialClass == $class)) | .[0].address // empty
')"

if [[ -n "$addr" ]]; then
  active_addr="$(hyprctl -j activewindow | jq -r '.address // empty')"
  if [[ "$active_addr" == "$addr" ]]; then
    hyprctl dispatch 'hl.dsp.window.close({ window = "address:'"${addr}"'" })' >/dev/null
  else
    hyprctl dispatch 'hl.dsp.focus({ window = "address:'"${addr}"'" })' >/dev/null
  fi
  exit 0
fi

# Первичный запуск в центрированном плавающем окне kitty
hyprctl dispatch 'hl.dsp.exec_cmd("kitty --class '"${class}"' --title '"${title}"' '"${app}"'", { float = true, size = { 879, 879 }, center = true })' >/dev/null
