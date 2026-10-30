#!/usr/bin/env bash
set -euo pipefail

SHM_NOTIFY_FILE="/dev/shm/waybar_notification.json"
SHM_ACTIVE_FILE="/dev/shm/waybar_notification_active"

APP="${SWAYNC_APP_NAME:-}"
SUMMARY="${SWAYNC_SUMMARY:-}"
BODY="${SWAYNC_BODY:-}"
URGENCY="${SWAYNC_URGENCY:-Normal}"
ID="${SWAYNC_ID:-0}"

# Если включен режим «Не беспокоить» (DND), не отправляем уведомления в статус-бар
if [[ "$(swaync-client -D 2>/dev/null)" == "true" ]]; then
    exit 0
fi

# Игнорируем регулировку громкости и яркости в Dynamic Island
if [[ "$SUMMARY" =~ ^(Brightness|Volume|Muted|Mic\ Muted|Mic\ Unmuted) ]]; then
    exit 0
fi

python3 -c '
import json, sys, time
data = {
    "app": sys.argv[1],
    "summary": sys.argv[2],
    "body": sys.argv[3],
    "urgency": sys.argv[4] if len(sys.argv) > 4 and sys.argv[4] else "Normal",
    "id": sys.argv[5] if len(sys.argv) > 5 else "0",
    "timestamp": time.time()
}
with open("/dev/shm/waybar_notification.json", "w") as f:
    json.dump(data, f)
' "$APP" "$SUMMARY" "$BODY" "$URGENCY" "$ID"

touch "$SHM_ACTIVE_FILE" 2>/dev/null || true
pkill -SIGUSR1 -f center_status.py 2>/dev/null || true
