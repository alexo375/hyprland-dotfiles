#!/usr/bin/env bash
# Очистка истории SwayNC и немедленный возврат центрального острова Waybar к статистике системы
swaync-client -C 2>/dev/null || true
rm -f /dev/shm/waybar_notification_active /dev/shm/waybar_notification.json 2>/dev/null || true
pkill -SIGUSR2 -f center_status.py 2>/dev/null || true
