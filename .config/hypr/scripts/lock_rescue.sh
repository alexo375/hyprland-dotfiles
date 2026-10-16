#!/usr/bin/env bash
set -euo pipefail

# Скрипт аварийного восстановления экрана блокировки (rescue lock).
# Применяется при зависании hyprlock или при входе через другой TTY (через бинарник misc/bin/hyprlock-rescue).
# Восстанавливает переменные окружения сессии Hyprland, перезапускает hypridle и запускает hyprlock.

uid="$(id -u)"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$uid}"

export XDG_RUNTIME_DIR="$runtime_dir"

# Извлечение переменных окружения (HYPRLAND_INSTANCE_SIGNATURE и WAYLAND_DISPLAY) из запущенного процесса Hyprland
hypr_pid="$(pgrep -xu "$USER" -n Hyprland || true)"
if [[ -n "$hypr_pid" && -r "/proc/$hypr_pid/environ" ]]; then
  while IFS='=' read -r key value; do
    case "$key" in
      HYPRLAND_INSTANCE_SIGNATURE|WAYLAND_DISPLAY)
        export "$key=$value"
        ;;
    esac
  done < <(tr '\0' '\n' < "/proc/$hypr_pid/environ")
fi

# Запасной поиск сигнатуры Hyprland в файловой системе run-каталога
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  sig_dir="$(find "$runtime_dir/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | tail -n 1 || true)"
  if [[ -n "$sig_dir" ]]; then
    export HYPRLAND_INSTANCE_SIGNATURE="$sig_dir"
  fi
fi

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  export WAYLAND_DISPLAY="wayland-1"
fi

# Завершение зависших инстансов блокировщика и таймеров
pkill -xu "$USER" hyprlock 2>/dev/null || true
pkill -xu "$USER" hypridle 2>/dev/null || true

# Включение DPMS монитора
for _ in $(seq 1 30); do
  if hyprctl dispatch dpms on >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

# Перезапуск демона idle и запуск нового hyprlock
hypridle >/dev/null 2>&1 &
disown || true

hyprlock >/dev/null 2>&1 &
disown || true
