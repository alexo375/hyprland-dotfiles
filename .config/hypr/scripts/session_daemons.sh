#!/usr/bin/env bash
set -euo pipefail

# Centralized management script for Hyprland session daemons and background services.
# Usage:
#   session_daemons.sh start    - Start all session daemons (skipping already running ones)
#   session_daemons.sh restart  - Cleanly restart all session daemons
#   session_daemons.sh stop     - Stop all session daemons
#   session_daemons.sh status   - Check status of each daemon

ACTION="${1:-start}"
HOME_DIR="${HOME:-/home/alex}"

stop_daemons() {
    systemctl --user stop cliphist-text cliphist-image wl-clip-persist quickshell media-listener bluetooth-events 2>/dev/null || true
    pkill -f 'wl-paste.*cliphist' 2>/dev/null || true
    pkill -x cliphist 2>/dev/null || true
    pkill -f 'bluetooth_events.py' 2>/dev/null || true
    pkill -f 'media_listener.py' 2>/dev/null || true
    pkill -f 'swaync' 2>/dev/null || true
    pkill -f 'awww-daemon' 2>/dev/null || true
    pkill -f 'quickshell.*overview' 2>/dev/null || true
    pkill -f 'qs -p.*/overview' 2>/dev/null || true
    pkill -f 'waybar' 2>/dev/null || true
    pkill -f 'wl-clip-persist' 2>/dev/null || true
    pkill -f 'polkit-gnome-authentication-agent-1' 2>/dev/null || true
    sleep 0.4
}

start_daemons() {
    # 1. QuickShell Overview
    if ! pgrep -f 'quickshell.*overview' >/dev/null 2>&1 && ! pgrep -f 'qs -p.*/overview' >/dev/null 2>&1; then
        systemd-run --user --unit=quickshell qs -p "$HOME_DIR/.config/quickshell/overview" -n >/dev/null 2>&1 || nohup qs -p "$HOME_DIR/.config/quickshell/overview" -n >/dev/null 2>&1 &
    fi

    # 2. Wallpaper daemon (awww)
    if ! pgrep -f 'awww-daemon' >/dev/null 2>&1; then
        nohup awww-daemon >/dev/null 2>&1 &
    fi

    # 3. Persistent clipboard
    if ! pgrep -f 'wl-clip-persist' >/dev/null 2>&1; then
        systemd-run --user --unit=wl-clip-persist wl-clip-persist --clipboard regular >/dev/null 2>&1 || nohup wl-clip-persist --clipboard regular >/dev/null 2>&1 &
    fi

    # 4. Notification Center (SwayNC)
    if ! pgrep -f 'swaync' >/dev/null 2>&1; then
        nohup swaync >/dev/null 2>&1 &
    fi

    # 5. Status bar (Waybar via start script)
    if ! pgrep -x waybar >/dev/null 2>&1 && ! pgrep -x .waybar-wrapped >/dev/null 2>&1; then
        nohup "$HOME_DIR/.config/hypr/scripts/waybar_start.sh" >/dev/null 2>&1 &
    fi

    # 6. Event listener scripts
    if ! pgrep -f 'bluetooth_events.py' >/dev/null 2>&1; then
        systemd-run --user --unit=bluetooth-events python3 "$HOME_DIR/.config/hypr/scripts/bluetooth_events.py" >/dev/null 2>&1 || nohup python3 "$HOME_DIR/.config/hypr/scripts/bluetooth_events.py" >/dev/null 2>&1 &
    fi

    if ! pgrep -f 'media_listener.py' >/dev/null 2>&1; then
        systemd-run --user --unit=media-listener python3 "$HOME_DIR/.config/hypr/scripts/media_listener.py" >/dev/null 2>&1 || nohup python3 "$HOME_DIR/.config/hypr/scripts/media_listener.py" >/dev/null 2>&1 &
    fi

    # 7. Clipboard history watchers (with timeout 5s against deadlocks)
    if ! pgrep -f 'wl-paste --type text --watch' >/dev/null 2>&1; then
        systemd-run --user --unit=cliphist-text wl-paste --type text --watch timeout 5s cliphist store >/dev/null 2>&1 || nohup wl-paste --type text --watch timeout 5s cliphist store >/dev/null 2>&1 &
    fi

    if ! pgrep -f 'wl-paste --type image --watch' >/dev/null 2>&1; then
        systemd-run --user --unit=cliphist-image wl-paste --type image --watch timeout 5s cliphist store >/dev/null 2>&1 || nohup wl-paste --type image --watch timeout 5s cliphist store >/dev/null 2>&1 &
    fi

    # 8. Polkit Agent
    systemctl --user start hyprpolkitagent 2>/dev/null || true

    disown -a 2>/dev/null || true
}

case "$ACTION" in
    start)
        start_daemons
        ;;
    restart)
        stop_daemons
        start_daemons
        notify-send -a "System" "Службы сессии" "Все демоны успешно перезапущены" 2>/dev/null || true
        ;;
    stop)
        stop_daemons
        ;;
    status)
        echo "=== Session Daemons Status ==="
        for proc in "quickshell" "awww-daemon" "wl-clip-persist" "swaync" "waybar" "bluetooth_events.py" "media_listener.py" "wl-paste" "hyprpolkitagent"; do
            if pgrep -f "$proc" >/dev/null 2>&1; then
                echo " [OK] $proc is running"
            else
                echo " [FAIL] $proc is NOT running"
            fi
        done
        ;;
    *)
        echo "Usage: $0 {start|restart|stop|status}"
        exit 1
        ;;
esac
