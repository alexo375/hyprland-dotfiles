#!/usr/bin/env bash
set -euo pipefail

SHM_ACTIVE_FILE="/dev/shm/waybar_notification_active"

if [[ -f "$SHM_ACTIVE_FILE" ]]; then
    # Notification currently shown: open SwayNC notification panel
    swaync-client -t -sw 2>/dev/null || true
else
    # System stats shown: open btop system monitor
    setsid kitty -e btop &
fi
