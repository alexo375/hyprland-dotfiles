#!/usr/bin/env bash

# Скрипт управления активным источником воспроизведения (MPRIS / playerctl)
# Поддерживает выбор целевого плеера, хоткеи управления и OSD-шкалу перемотки.
# Уведомления о воспроизведении обрабатываются реактивно через media_listener.py.

STATE_FILE="/tmp/active_media_player_${UID}"

get_players() {
    playerctl -l 2>/dev/null | grep -v '^$'
}

get_player_identity() {
    local raw="$1"
    local identity=""
    identity=$(busctl --user get-property "org.mpris.MediaPlayer2.${raw}" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2 Identity 2>/dev/null | cut -d'"' -f2)
    if [ -n "$identity" ]; then
        echo "$identity"
        return
    fi
    echo "${raw%%.*}" | tr '_-' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1'
}

send_island_notification() {
    local summary="$1"
    local body="$2"
    local icon="${3:-󰝚}"
    local duration="${4:-2.0}"

    python3 -c '
import json, sys, time
data = {
    "app": "Media",
    "summary": sys.argv[1].replace("\\n", " "),
    "body": sys.argv[2].replace("\\n", "\n"),
    "icon": sys.argv[3],
    "duration": float(sys.argv[4]),
    "timestamp": time.time()
}
with open("/dev/shm/waybar_notification.json", "w") as f:
    json.dump(data, f)
' "$summary" "$body" "$icon" "$duration" 2>/dev/null || true

    touch /dev/shm/waybar_notification_active 2>/dev/null || true
    pkill -SIGUSR1 -f "^python3 .*center_status\.py" 2>/dev/null || true
}

get_current_target() {
    local saved=""
    [ -f "$STATE_FILE" ] && saved=$(cat "$STATE_FILE" 2>/dev/null)

    local mapfile_players
    mapfile -t mapfile_players < <(get_players)

    if [ ${#mapfile_players[@]} -eq 0 ]; then
        echo ""
        return
    fi

    # Проверяем сохраненный плеер среди доступных
    if [ -n "$saved" ]; then
        for p in "${mapfile_players[@]}"; do
            if [ "$p" == "$saved" ]; then
                echo "$p"
                return
            fi
        done
    fi

    # Иначе ищем первый играющий
    for p in "${mapfile_players[@]}"; do
        local st
        st=$(playerctl --player="$p" status 2>/dev/null)
        if [ "$st" == "Playing" ]; then
            echo "$p"
            return
        fi
    done

    echo "${mapfile_players[0]}"
}

action_switch() {
    local direction="$1" # "next" или "prev"
    mapfile -t players < <(get_players)
    local total=${#players[@]}

    if [ "$total" -eq 0 ]; then
        send_island_notification "Media" "No media players found" "󰝚" 2.0
        exit 0
    fi

    local current
    current=$(get_current_target)
    local cur_idx=0

    for i in "${!players[@]}"; do
        if [ "${players[$i]}" == "$current" ]; then
            cur_idx=$i
            break
        fi
    done

    local new_idx
    if [ "$direction" == "prev" ]; then
        new_idx=$(( (cur_idx - 1 + total) % total ))
    else
        new_idx=$(( (cur_idx + 1) % total ))
    fi

    local target="${players[$new_idx]}"
    echo "$target" > "$STATE_FILE"

    local friendly_name
    friendly_name=$(get_player_identity "$target")
    local status
    status=$(playerctl --player="$target" status 2>/dev/null || echo "Unknown")
    local track
    track=$(playerctl --player="$target" metadata --format '{{artist}} — {{title}}' 2>/dev/null || echo "")

    local body="$friendly_name"
    [ -n "$track" ] && body="${friendly_name}"$'\n'"${status} • ${track}"
    send_island_notification "Media Source" "$body" "󰝚" 2.0
}

show_seek_osd() {
    local player="$1"
    python3 -c '
import subprocess, json, sys

player = sys.argv[1]
try:
    pos = float(subprocess.check_output(["playerctl", f"--player={player}", "position"], stderr=subprocess.DEVNULL).decode().strip())
    length_us = float(subprocess.check_output(["playerctl", f"--player={player}", "metadata", "mpris:length"], stderr=subprocess.DEVNULL).decode().strip())
    length_s = length_us / 1000000.0
    pct = int(round((pos / length_s) * 100)) if length_s > 0 else 0
    time_str = subprocess.check_output(["playerctl", f"--player={player}", "metadata", "--format", "{{duration(position)}} / {{duration(mpris:length)}}"], stderr=subprocess.DEVNULL).decode().strip()
except Exception:
    time_str = "Seeking"
    pct = -1

data = {
    "app": "osd",
    "icon": "󰝚",
    "summary": time_str,
    "value": pct,
    "duration": 1.5
}
with open("/dev/shm/waybar_notification.json", "w") as f:
    json.dump(data, f)
with open("/dev/shm/waybar_notification_active", "w") as f:
    f.write("1")
' "$player" 2>/dev/null || true

    pkill -SIGUSR1 -f "^python3 .*center_status\.py" 2>/dev/null || true
}

action_cmd() {
    local cmd="$1"
    shift
    local target
    target=$(get_current_target)

    if [ -n "$target" ]; then
        echo "$target" > "$STATE_FILE"
        playerctl --player="$target" "$cmd" "$@"
    else
        playerctl "$cmd" "$@"
    fi
}

case "$1" in
    switch-next)
        action_switch "next"
        ;;
    switch-prev)
        action_switch "prev"
        ;;
    play-pause)
        action_cmd play-pause
        ;;
    next)
        action_cmd next
        ;;
    previous)
        action_cmd previous
        ;;
    position)
        target=$(get_current_target)
        if [ -n "$target" ]; then
            playerctl --player="$target" position "$2"
            show_seek_osd "$target"
        fi
        ;;
    status)
        target=$(get_current_target)
        if [ -n "$target" ]; then
            friendly=$(get_player_identity "$target")
            st=$(playerctl --player="$target" status 2>/dev/null || echo "Unknown")
            tr=$(playerctl --player="$target" metadata --format '{{artist}} — {{title}}' 2>/dev/null || echo "")
            send_island_notification "Media Source" "${friendly}"$'\n'"${st} • ${tr}" "󰝚" 2.0
        fi
        ;;
    *)
        echo "Usage: $0 {switch-next|switch-prev|play-pause|next|previous|position <offset>|status}"
        exit 1
        ;;
esac
