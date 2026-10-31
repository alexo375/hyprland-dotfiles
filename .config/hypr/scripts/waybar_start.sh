#!/usr/bin/env bash
set -euo pipefail

# Скрипт корректного автозапуска Waybar при старте сессии Hyprland:
# 1. Завершает старые/зависшие процессы Waybar.
# 2. Ожидает появления сокета Hyprland IPC (.socket2.sock).
# 3. Запускает порталы xdg-desktop-portal для предотвращения задержки старта темы (~25 сек).
# 4. Запускает Waybar в фоновом режиме.

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Инициализация дефолтной темы, если цвета еще не сгенерированы
if [[ ! -f "$HOME/.config/colors/colors.css" && -d "$HOME/.config/colors/defaults" ]]; then
  cp -r "$HOME/.config/colors/defaults/"* "$HOME/.config/colors/" 2>/dev/null || true
fi

# Завершение предыдущих инстансов Waybar
pkill -x waybar 2>/dev/null || true
pkill -x .waybar-wrapped 2>/dev/null || true

for _ in $(seq 1 10); do
  pgrep -x waybar >/dev/null 2>&1 || pgrep -x .waybar-wrapped >/dev/null 2>&1 || break
  sleep 0.1
done

# Ожидание готовности сокета Hyprland для мгновенного подключения модулей воркспейсов
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  socket="$runtime_dir/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
  for _ in $(seq 1 10); do
    [[ -S "$socket" ]] && break
    sleep 0.1
  done
fi

# Прогрев порталов рабочего стола для предотвращения зависания Waybar при запросе цветовой схемы
systemctl --user start xdg-desktop-portal.service xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service 2>/dev/null || true
for _ in $(seq 1 20); do
  systemctl --user is-active --quiet xdg-desktop-portal.service && break
  sleep 0.1
done

# Запуск Waybar без блокировки родительского шелла
setsid -f waybar -l off >/dev/null 2>&1 || (nohup waybar -l off >/dev/null 2>&1 &)
disown || true
