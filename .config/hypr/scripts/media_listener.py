#!/usr/bin/env python3
"""
Media Track Change & State Monitor Daemon.
Follows Unix philosophy: one tool for one job.
Listens for MPRIS/playerctl state and track transitions and updates Waybar Dynamic Island.
Universal: queries MPRIS Identity property directly via D-Bus, works with any player.
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

def get_friendly_player_name(raw_name):
    """Universal player name resolver: queries standard MPRIS Identity property from D-Bus."""
    try:
        out = subprocess.check_output(
            ["busctl", "--user", "get-property", f"org.mpris.MediaPlayer2.{raw_name}", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2", "Identity"],
            text=True, stderr=subprocess.DEVNULL, timeout=0.3
        )
        if '"' in out:
            val = out.split('"', 1)[1].rsplit('"', 1)[0].strip()
            if val:
                return val
    except Exception:
        pass
    # Universal fallback: clean up bus name (e.g. 'iphone-music-player.instance12' -> 'Iphone Music Player')
    clean = raw_name.split(".")[0].replace("-", " ").replace("_", " ").title()
    return clean or raw_name

def send_island(summary, body, icon="󰝚", duration=2.0):
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

def main():
    check_single_instance()
    last_state = (None, None)

    # Pre-populate initial state so we don't spam a notification on boot/login
    try:
        init_st = subprocess.check_output(["playerctl", "status"], text=True, stderr=subprocess.DEVNULL).strip()
        init_tr = subprocess.check_output(["playerctl", "metadata", "--format", "{{artist}} — {{title}}"], text=True, stderr=subprocess.DEVNULL).strip()
        last_state = (init_st, init_tr)
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

                # Ignore empty metadata transitions or stopped state
                if not title or status not in ("Playing", "Paused"):
                    continue

                track = f"{artist} — {title}" if artist else title
                current_state = (status, track)

                if current_state != last_state:
                    last_state = current_state
                    friendly_name = get_friendly_player_name(player_name)
                    send_island(
                        summary=status,
                        body=f"{track}\n{friendly_name}",
                        icon="󰝚",
                        duration=2.0
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
