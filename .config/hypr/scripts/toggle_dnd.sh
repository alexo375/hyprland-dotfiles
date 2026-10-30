#!/usr/bin/env bash
set -euo pipefail

# Переключаем режим «Не беспокоить» (DND)
swaync-client -d -sw

# Если режим DND включился, немедленно очищаем статус-бар и возвращаем системную статистику
if [[ "$(swaync-client -D 2>/dev/null)" == "true" ]]; then
    rm -f /dev/shm/waybar_notification_active /dev/shm/waybar_notification.json 2>/dev/null || true
    pkill -SIGUSR2 -f center_status.py 2>/dev/null || true
fi
