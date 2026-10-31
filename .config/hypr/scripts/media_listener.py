#!/usr/bin/env python3
"""
Media Track Change Monitor Daemon.
Follows Unix philosophy: one tool for one job.
Listens for MPRIS/playerctl track changes and displays Dynamic Island notifications
when songs transition automatically.
"""

import os
import sys
import time
import json
import signal
import subprocess

LOCK_FILE = f"/tmp/media_listener_daemon_{os.getuid()}.pid"
SHM_FILE = "/dev/shm/waybar_notification.json"
SHM_ACTIVE = "/dev/shm/waybar_notification_active"

running = True

def signal_handler(signum, frame):
    global running
    running = False

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

def check_single_instance():
    if os.path.exists(LOCK_FILE):
        try:
            with open(LOCK_FILE, "r") as f:
                old_pid = int(f.read().strip())
            os.kill(old_pid, 0)
            sys.exit(0)
        except (OSError, ValueError):
            pass
    try:
        with open(LOCK_FILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass

def format_player_name(raw):
    raw_lower = raw.lower()
    if "yandex" in raw_lower or "yamusic" in raw_lower:
        return "Yandex Music (TUI)"
    if "spotify" in raw_lower:
        return "Spotify"
    if "firefox" in raw_lower:
        return "Firefox"
    if "chromium" in raw_lower or "chrome" in raw_lower:
        return "Chromium"
    if "mpv" in raw_lower:
        return "MPV"
    if "vlc" in raw_lower:
        return "VLC"
    return raw.split(".")[0].capitalize()

def send_island(summary, body, icon="󰝚", duration=2.5):
    try:
        data = {
            "app": "Media",
            "summary": summary,
            "body": body,
            "icon": icon,
            "duration": float(duration),
            "timestamp": time.time()
        }
        with open(SHM_FILE, "w") as f:
            json.dump(data, f)
        with open(SHM_ACTIVE, "w") as f:
            f.write("1")
        subprocess.run(["pkill", "-SIGUSR1", "-f", "^python3 .*center_status\\.py"], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def was_recently_notified(track):
    """Avoid duplicate toast if hotkey script media_control.sh just triggered it."""
    try:
        if os.path.exists(SHM_FILE):
            with open(SHM_FILE, "r") as f:
                data = json.load(f)
            if data.get("app") == "Media":
                ts = data.get("timestamp", 0)
                body = data.get("body", "")
                if (time.time() - ts) < 2.0 and track in body:
                    return True
    except Exception:
        pass
    return False

def main():
    check_single_instance()
    last_track = ""

    # Pre-populate initial playing track so we don't alert on startup
    try:
        init_out = subprocess.check_output(
            ["playerctl", "metadata", "--format", "{{artist}} — {{title}}"],
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
        last_track = init_out
    except Exception:
        pass

    while running:
        proc = None
        try:
            proc = subprocess.Popen(
                ["playerctl", "-F", "metadata", "--format", "{{status}}:::{{artist}}:::{{title}}:::{{playerName}}"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1
            )

            for line in proc.stdout:
                if not running:
                    break
                line = line.strip()
                if not line or ":::" not in line:
                    continue

                parts = line.split(":::")
                if len(parts) < 4:
                    continue

                status, artist, title, player_name = parts[0], parts[1], parts[2], parts[3]

                # Only notify when track is playing and title is present
                if status != "Playing" or not title:
                    continue

                track = f"{artist} — {title}" if artist else title
                friendly_name = format_player_name(player_name)

                # Has the track genuinely changed?
                if track != last_track:
                    last_track = track
                    if not was_recently_notified(track):
                        send_island(
                            summary="Playing",
                            body=f"{track}\n{friendly_name}",
                            icon="󰝚",
                            duration=2.5
                        )

        except Exception:
            pass
        finally:
            if proc:
                try:
                    proc.terminate()
                    proc.wait(timeout=1.0)
                except Exception:
                    pass

        if running:
            time.sleep(2.0)

    if os.path.exists(LOCK_FILE):
        try:
            os.remove(LOCK_FILE)
        except Exception:
            pass

if __name__ == "__main__":
    main()
