#!/usr/bin/env python3
"""
Media Track Change & State Monitor Daemon for Hyprland / Waybar Dynamic Island.
Native D-Bus implementation via PyQt6 DBusQtMainLoop.
Eliminates brittle playerctl child-process pipelines and reacts instantly to:
- Playback status changes (Playing, Paused)
- Track changes (Artist, Title, Album)
- Player lifecycle (browser tab opens, closes, reloads)
"""

import os
import sys
import time
import json
import signal
import subprocess
from PyQt6.QtCore import QCoreApplication, QTimer
from dbus.mainloop.pyqt6 import DBusQtMainLoop
import dbus

LOCK_FILE = f"/tmp/media_listener_daemon_{os.getuid()}.pid"
SHM_FILE = "/dev/shm/waybar_notification.json"
SHM_ACTIVE = "/dev/shm/waybar_notification_active"

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

TRACK_CHANGE_DURATION = 6.0
PLAY_PAUSE_DURATION = 3.5

def send_island(summary, body, icon="󰝚", duration=TRACK_CHANGE_DURATION):
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
        subprocess.run(["pkill", "-SIGUSR1", "-f", "center_status\\.py"], stderr=subprocess.DEVNULL)
    except Exception:
        pass

class MediaWatcher:
    def __init__(self, bus):
        self.bus = bus
        # Map: bus_name -> {"identity": str, "status": str, "track": str}
        self.players = {}
        self.active_player = None
        self.last_notified_track = None

        # Hook D-Bus signals
        self.bus.add_signal_receiver(
            self.on_properties_changed,
            signal_name="PropertiesChanged",
            dbus_interface="org.freedesktop.DBus.Properties",
            path_keyword="path",
            sender_keyword="sender"
        )
        self.bus.add_signal_receiver(
            self.on_name_owner_changed,
            signal_name="NameOwnerChanged",
            dbus_interface="org.freedesktop.DBus",
            arg0="org.freedesktop.DBus"
        )

        # Initial scan of available players
        self.scan_players()

    def get_identity(self, bus_name):
        try:
            obj = self.bus.get_object(bus_name, "/org/mpris/MediaPlayer2")
            props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
            identity = props.Get("org.mpris.MediaPlayer2", "Identity")
            if identity:
                name = str(identity).strip()
                if name.lower() == "yandex-music":
                    return "Яндекс Музыка"
                return name
        except Exception:
            pass

        # Fallback to readable bus name
        clean = bus_name.replace("org.mpris.MediaPlayer2.", "").split(".")[0]
        return clean.replace("-", " ").replace("_", " ").title()

    def get_player_state(self, bus_name):
        try:
            obj = self.bus.get_object(bus_name, "/org/mpris/MediaPlayer2")
            props = dbus.Interface(obj, "org.freedesktop.DBus.Properties")
            status = str(props.Get("org.mpris.MediaPlayer2.Player", "PlaybackStatus"))
            meta = props.Get("org.mpris.MediaPlayer2.Player", "Metadata")
            artist = ""
            if "xesam:artist" in meta:
                raw_artist = meta["xesam:artist"]
                if isinstance(raw_artist, (list, dbus.Array)) and len(raw_artist) > 0:
                    artist = str(raw_artist[0])
                else:
                    artist = str(raw_artist)
            title = str(meta.get("xesam:title", "")).strip()
            track = f"{artist} — {title}" if (artist and title) else title
            return status, track
        except Exception:
            return None, None

    def scan_players(self):
        try:
            for name in self.bus.list_names():
                if name.startswith("org.mpris.MediaPlayer2."):
                    identity = self.get_identity(name)
                    status, track = self.get_player_state(name)
                    if status:
                        self.players[name] = {
                            "identity": identity,
                            "status": status,
                            "track": track
                        }
                        if status == "Playing" and not self.active_player:
                            self.active_player = name
            if not self.active_player and self.players:
                self.active_player = next(iter(self.players))
        except Exception:
            pass

    def on_name_owner_changed(self, name, old_owner, new_owner):
        if not name.startswith("org.mpris.MediaPlayer2."):
            return

        if not new_owner and name in self.players:
            # Player quit / closed
            del self.players[name]
            if self.active_player == name:
                self.active_player = next(iter(self.players)) if self.players else None
        elif new_owner and not old_owner:
            # New player registered
            QTimer.singleShot(200, lambda n=name: self.handle_new_player(n))

    def handle_new_player(self, name):
        identity = self.get_identity(name)
        status, track = self.get_player_state(name)
        if status:
            self.players[name] = {
                "identity": identity,
                "status": status,
                "track": track
            }
            if status == "Playing" or not self.active_player:
                self.active_player = name

    def on_properties_changed(self, interface, changed_props, invalidated_props, path=None, sender=None):
        if interface != "org.mpris.MediaPlayer2.Player" or path != "/org/mpris/MediaPlayer2":
            return

        # Find matching player in self.players by checking names
        # D-Bus sender is unique name (e.g. :1.390); resolve to well-known name
        target_name = None
        for name in list(self.players.keys()):
            try:
                owner = self.bus.get_name_owner(name)
                if owner == sender:
                    target_name = name
                    break
            except Exception:
                continue

        if not target_name:
            # Might be an unindexed player or directly registered
            for name in self.bus.list_names():
                if name.startswith("org.mpris.MediaPlayer2."):
                    try:
                        if self.bus.get_name_owner(name) == sender:
                            target_name = name
                            self.handle_new_player(name)
                            break
                    except Exception:
                        continue

        if not target_name or target_name not in self.players:
            return

        info = self.players[target_name]
        prev_status = info.get("status")
        prev_track = info.get("track")

        has_status_change = "PlaybackStatus" in changed_props
        has_meta_change = "Metadata" in changed_props

        if not has_status_change and not has_meta_change:
            return

        new_status = str(changed_props["PlaybackStatus"]) if has_status_change else prev_status
        new_track = prev_track

        if has_meta_change:
            meta = changed_props["Metadata"]
            artist = ""
            if "xesam:artist" in meta:
                raw_artist = meta["xesam:artist"]
                if isinstance(raw_artist, (list, dbus.Array)) and len(raw_artist) > 0:
                    artist = str(raw_artist[0])
                else:
                    artist = str(raw_artist)
            title = str(meta.get("xesam:title", "")).strip()
            new_track = f"{artist} — {title}" if (artist and title) else title

        # Update cache
        info["status"] = new_status
        info["track"] = new_track
        self.active_player = target_name

        # Trigger notification only if status or track actually changed
        track_changed = (new_track != prev_track and bool(new_track))
        status_changed = (new_status != prev_status)

        if (track_changed or status_changed) and new_status in ("Playing", "Paused") and new_track:
            icon = "󰝚" if new_status == "Playing" else "󰏤"
            # Если изменился трек или это первый анонс этого трека — держим 6 секунд
            if new_track != self.last_notified_track:
                self.last_notified_track = new_track
                duration = TRACK_CHANGE_DURATION
            else:
                duration = PLAY_PAUSE_DURATION

            send_island(
                summary=new_status,
                body=f"{new_track}\n{info['identity']}",
                icon=icon,
                duration=duration
            )

def main():
    check_single_instance()

    # Integrate PyQt6 event loop with DBus
    DBusQtMainLoop(set_as_default=True)
    app = QCoreApplication(sys.argv)
    bus = dbus.SessionBus()

    watcher = MediaWatcher(bus)

    def handle_exit(signum, frame):
        if os.path.exists(LOCK_FILE):
            try:
                os.remove(LOCK_FILE)
            except Exception:
                pass
        app.quit()

    signal.signal(signal.SIGINT, handle_exit)
    signal.signal(signal.SIGTERM, handle_exit)

    # Periodic timer to allow Python signal processing
    timer = QTimer()
    timer.timeout.connect(lambda: None)
    timer.start(500)

    try:
        sys.exit(app.exec())
    finally:
        if os.path.exists(LOCK_FILE):
            try:
                os.remove(LOCK_FILE)
            except Exception:
                pass

if __name__ == "__main__":
    main()
