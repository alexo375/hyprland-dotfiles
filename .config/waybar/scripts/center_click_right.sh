#!/usr/bin/env bash
set -euo pipefail

SHM_NOTIFY_FILE="/dev/shm/waybar_notification.json"
SHM_ACTIVE_FILE="/dev/shm/waybar_notification_active"

if [[ -f "$SHM_ACTIVE_FILE" ]]; then
    # Dismiss active notification immediately
    rm -f "$SHM_ACTIVE_FILE" "$SHM_NOTIFY_FILE" 2>/dev/null || true
    pkill -SIGUSR2 -f center_status.py 2>/dev/null || true
    swaync-client --close-latest 2>/dev/null || true
else
    # In sysstats mode: right click toggles notification center
    swaync-client -t -sw 2>/dev/null || true
fi
