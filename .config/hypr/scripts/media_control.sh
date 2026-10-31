#!/usr/bin/env bash

# Скрипт управления активным источником воспроизведения (MPRIS / playerctl)
# Позволяет переключать целевой плеер между несколькими источниками (Firefox, ymtui и др.)
# и отправляет OSD-уведомление без спама в историю swaync.

STATE_FILE="/tmp/active_media_player_${UID}"
NID_FILE="/tmp/active_media_player_nid_${UID}"

get_players() {
    playerctl -l 2>/dev/null | grep -v '^$'
}

format_player_name() {
    local raw="$1"
    case "$raw" in
        yandex-music-tui*|yamusic*)
            echo "Yandex Music (TUI)"
            ;;
        firefox*)
            echo "Firefox"
            ;;
        chromium*|google-chrome*)
            echo "Chromium"
            ;;
        spotify*)
            echo "Spotify"
            ;;
        mpv*)
            echo "MPV"
            ;;
        vlc*)
            echo "VLC"
            ;;
        *)
            # Отрезаем суффикс instance если есть
            echo "${raw%%.*}"
            ;;
    esac
}

show_notification() {
    local player="$1"
    local friendly_name
    friendly_name=$(format_player_name "$player")

    local status
    status=$(playerctl --player="$player" status 2>/dev/null || echo "Unknown")

    local status_text
    local status_icon
    case "$status" in
        Playing)
            status_text="Playing"
            status_icon="media-playback-start-symbolic"
            ;;
        Paused)
            status_text="Paused"
            status_icon="media-playback-pause-symbolic"
            ;;
        *)
            status_text="Stopped"
            status_icon="media-playback-stop-symbolic"
            ;;
    esac

    local artist title track_info
    artist=$(playerctl --player="$player" metadata --format '{{artist}}' 2>/dev/null)
    title=$(playerctl --player="$player" metadata --format '{{title}}' 2>/dev/null)
    if [ -z "$artist" ] && [ -z "$title" ]; then
        for ((i=0; i<4; i++)); do
            sleep 0.05
            artist=$(playerctl --player="$player" metadata --format '{{artist}}' 2>/dev/null)
            title=$(playerctl --player="$player" metadata --format '{{title}}' 2>/dev/null)
            if [ -n "$artist" ] || [ -n "$title" ]; then
                break
            fi
        done
    fi

    if [ -n "$artist" ] && [ -n "$title" ]; then
        track_info="${artist} — ${title}"
    elif [ -n "$title" ]; then
        track_info="${title}"
    elif [ -n "$artist" ]; then
        track_info="${artist}"
    else
        track_info="No track info"
    fi

    local old_nid=""
    if [ -f "$NID_FILE" ]; then
        old_nid=$(cat "$NID_FILE" 2>/dev/null)
    fi

    local replace_arg=()
    if [ -n "$old_nid" ] && [ "$old_nid" -gt 0 ] 2>/dev/null; then
        replace_arg=("-r" "$old_nid")
    fi

    local new_nid
    new_nid=$(notify-send -p -e "${replace_arg[@]}" \
        -h string:x-canonical-private-synchronous:media_player \
        -h boolean:transient:true \
        -u low -t 2000 \
        -i "$status_icon" \
        -a "Media" \
        "Media Source" \
        "$friendly_name\n$status_text • $track_info")

    if [ -n "$new_nid" ]; then
        echo "$new_nid" > "$NID_FILE"
    fi
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

    # Проверяем, есть ли сохраненный плеер среди доступных
    if [ -n "$saved" ]; then
        for p in "${mapfile_players[@]}"; do
            if [ "$p" == "$saved" ]; then
                echo "$p"
                return
            fi
        done
    fi

    # Иначе ищем первый плеер, который играет (Playing)
    for p in "${mapfile_players[@]}"; do
        local st
        st=$(playerctl --player="$p" status 2>/dev/null)
        if [ "$st" == "Playing" ]; then
            echo "$p"
            return
        fi
    done

    # По умолчанию первый доступный
    echo "${mapfile_players[0]}"
}

action_switch() {
    local direction="$1" # "next" или "prev"
    mapfile -t players < <(get_players)
    local total=${#players[@]}

    if [ "$total" -eq 0 ]; then
        notify-send -a "Media" -e -u low -t 1500 -i audio-volume-muted-symbolic "Media" "No media players found"
        exit 0
    fi

    if [ "$total" -eq 1 ]; then
        echo "${players[0]}" > "$STATE_FILE"
        show_notification "${players[0]}"
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
    show_notification "$target"
}

show_playback_notification() {
    local action="$1"
    local player="$2"
    local forced_status="${3:-}"
    local forced_artist="${4:-}"
    local forced_title="${5:-}"

    local friendly_name
    friendly_name=$(format_player_name "$player")

    local status="$forced_status"
    if [ -z "$status" ]; then
        status=$(playerctl --player="$player" status 2>/dev/null || echo "Unknown")
    fi

    local summary
    local status_icon
    case "$action" in
        play-pause)
            if [ "$status" == "Playing" ]; then
                summary="Playing"
                status_icon="media-playback-start-symbolic"
            else
                summary="Paused"
                status_icon="media-playback-pause-symbolic"
            fi
            ;;
        next)
            summary="Next Track"
            status_icon="media-skip-forward-symbolic"
            ;;
        previous)
            summary="Previous Track"
            status_icon="media-skip-backward-symbolic"
            ;;
        *)
            summary="$action"
            status_icon="media-playback-start-symbolic"
            ;;
    esac

    local artist="$forced_artist"
    local title="$forced_title"
    if [ -z "$artist" ] && [ -z "$title" ]; then
        artist=$(playerctl --player="$player" metadata --format '{{artist}}' 2>/dev/null)
        title=$(playerctl --player="$player" metadata --format '{{title}}' 2>/dev/null)
    fi

    local track_info
    if [ -n "$artist" ] && [ -n "$title" ]; then
        track_info="${artist} — ${title}"
    elif [ -n "$title" ]; then
        track_info="${title}"
    elif [ -n "$artist" ]; then
        track_info="${artist}"
    else
        track_info="No track info"
    fi

    local old_nid=""
    [ -f "$NID_FILE" ] && old_nid=$(cat "$NID_FILE" 2>/dev/null)

    local replace_arg=()
    if [ -n "$old_nid" ] && [ "$old_nid" -gt 0 ] 2>/dev/null; then
        replace_arg=("-r" "$old_nid")
    fi

    local new_nid
    new_nid=$(notify-send -p -e "${replace_arg[@]}" \
        -h string:x-canonical-private-synchronous:media_playback \
        -h boolean:transient:true \
        -u low -t 2000 \
        -i "$status_icon" \
        -a "Media" \
        "$summary" \
        "$track_info\n$friendly_name")

    if [ -n "$new_nid" ]; then
        echo "$new_nid" > "$NID_FILE"
    fi
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
    status)
        target=$(get_current_target)
        if [ -n "$target" ]; then
            show_notification "$target"
        fi
        ;;
    play-pause)
        target=$(get_current_target)
        if [ -n "$target" ]; then
            echo "$target" > "$STATE_FILE"
            old_status=$(playerctl --player="$target" status 2>/dev/null || true)
            playerctl --player="$target" play-pause

            # Опрашиваем смену статуса до 700мс (14 x 50мс), выходим мгновенно при смене
            new_status=""
            for ((i=0; i<14; i++)); do
                sleep 0.05
                cur=$(playerctl --player="$target" status 2>/dev/null || true)
                if [ -n "$cur" ] && [ "$cur" != "$old_status" ]; then
                    new_status="$cur"
                    break
                fi
            done

            if [ -z "$new_status" ]; then
                cur=$(playerctl --player="$target" status 2>/dev/null || true)
                if [ -n "$cur" ] && [ "$cur" != "$old_status" ]; then
                    new_status="$cur"
                elif [ "$old_status" == "Playing" ]; then
                    new_status="Paused"
                elif [ "$old_status" == "Paused" ]; then
                    new_status="Playing"
                else
                    new_status="${cur:-Playing}"
                fi
            fi

            artist=$(playerctl --player="$target" metadata --format '{{artist}}' 2>/dev/null || true)
            title=$(playerctl --player="$target" metadata --format '{{title}}' 2>/dev/null || true)
            if [ -z "$artist" ] && [ -z "$title" ]; then
                for ((i=0; i<4; i++)); do
                    sleep 0.05
                    artist=$(playerctl --player="$target" metadata --format '{{artist}}' 2>/dev/null || true)
                    title=$(playerctl --player="$target" metadata --format '{{title}}' 2>/dev/null || true)
                    if [ -n "$artist" ] || [ -n "$title" ]; then
                        break
                    fi
                done
            fi

            show_playback_notification "play-pause" "$target" "$new_status" "$artist" "$title"
        fi
        ;;
    next|previous)
        action="$1"
        target=$(get_current_target)
        if [ -n "$target" ]; then
            echo "$target" > "$STATE_FILE"
            old_artist=$(playerctl --player="$target" metadata --format '{{artist}}' 2>/dev/null || true)
            old_title=$(playerctl --player="$target" metadata --format '{{title}}' 2>/dev/null || true)
            old_track="${old_artist} - ${old_title}"

            playerctl --player="$target" "$action"

            # Опрашиваем смену метаданных до 800мс (16 x 50мс), выходим мгновенно при получении нового трека
            cur_artist=""
            cur_title=""
            for ((i=0; i<16; i++)); do
                sleep 0.05
                cur_artist=$(playerctl --player="$target" metadata --format '{{artist}}' 2>/dev/null || true)
                cur_title=$(playerctl --player="$target" metadata --format '{{title}}' 2>/dev/null || true)
                cur_track="${cur_artist} - ${cur_title}"

                if { [ -n "$cur_title" ] || [ -n "$cur_artist" ]; } && [ "$cur_track" != "$old_track" ] && [ "$cur_track" != " - " ]; then
                    break
                fi
            done

            if [ -z "$cur_title" ] && [ -z "$cur_artist" ]; then
                cur_artist=$(playerctl --player="$target" metadata --format '{{artist}}' 2>/dev/null || true)
                cur_title=$(playerctl --player="$target" metadata --format '{{title}}' 2>/dev/null || true)
            fi

            if [ -z "$cur_title" ] && [ -z "$cur_artist" ] && [ -n "$old_title" ]; then
                cur_artist="$old_artist"
                cur_title="$old_title"
            fi

            cur_status=$(playerctl --player="$target" status 2>/dev/null || echo "Playing")
            show_playback_notification "$action" "$target" "$cur_status" "$cur_artist" "$cur_title"
        fi
        ;;
    position)
        action_cmd position "$2"
        target=$(get_current_target)
        if [ -n "$target" ]; then
            show_seek_osd "$target"
        fi
        ;;
    *)
        echo "Usage: $0 {switch-next|switch-prev|play-pause|next|previous|position <offset>|status}"
        exit 1
        ;;
esac
