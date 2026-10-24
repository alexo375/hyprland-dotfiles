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
            echo "Яндекс Музыка (TUI)"
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
            status_text="▶ Играет"
            status_icon="media-playback-start-symbolic"
            ;;
        Paused)
            status_text="⏸ На паузе"
            status_icon="media-playback-pause-symbolic"
            ;;
        *)
            status_text="⏹ Остановлен"
            status_icon="media-playback-stop-symbolic"
            ;;
    esac

    local artist title track_info
    artist=$(playerctl --player="$player" metadata --format '{{artist}}' 2>/dev/null)
    title=$(playerctl --player="$player" metadata --format '{{title}}' 2>/dev/null)

    if [ -n "$artist" ] && [ -n "$title" ]; then
        track_info="${artist} — ${title}"
    elif [ -n "$title" ]; then
        track_info="${title}"
    elif [ -n "$artist" ]; then
        track_info="${artist}"
    else
        track_info="Нет информации о треке"
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
        -u low -t 2000 \
        -i "$status_icon" \
        "Управление: $friendly_name" \
        "$status_text  •  $track_info")

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
        notify-send -e -u low -t 1500 -i audio-volume-muted-symbolic "Медиаплееры не найдены"
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
        action_cmd play-pause
        ;;
    next)
        action_cmd next
        ;;
    previous)
        action_cmd previous
        ;;
    position)
        action_cmd position "$2"
        ;;
    *)
        echo "Usage: $0 {switch-next|switch-prev|play-pause|next|previous|position <offset>|status}"
        exit 1
        ;;
esac
