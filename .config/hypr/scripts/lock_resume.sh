#!/usr/bin/env bash
set -euo pipefail

# Скрипт возобновления работы экрана после сна (resume) и запуска блокировщика:
# 1. При необходимости запускает hyprlock.
# 2. Ожидает готовности IPC-сокета Hyprland при выходе из спящего режима.
# 3. Включает питание монитора через 'hyprctl dispatch dpms on'.

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
resume_only=0

# Флаг --resume передается из hypridle (after_sleep_cmd)
if [[ "${1:-}" == "--resume" ]]; then
  resume_only=1
fi

# Ожидание появления сокета Hyprland (при выходе из сна возможна гонка процессов)
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  socket="$runtime_dir/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  for _ in $(seq 1 30); do
    [[ -S "$socket" ]] && break
    sleep 0.1
  done
fi

# Если скрипт вызван не только для resume, проверяем и запускаем hyprlock в фоне
if [[ "$resume_only" == "0" ]] && ! pgrep -xu "$USER" hyprlock >/dev/null 2>&1; then
  hyprlock >/dev/null 2>&1 &
  disown || true
fi

# Включение DPMS монитора с повторными попытками до успешного ответа композитора
dpms_ok=0
for _ in $(seq 1 30); do
  if hyprctl dispatch dpms on >/dev/null 2>&1; then
    dpms_ok=1
    break
  fi
  sleep 0.1
done

exit 0
