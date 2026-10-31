#!/usr/bin/env python3
"""
Bluetooth Event Monitor Daemon for Hyprland / Waybar / SwayNC.
Listens to bluetoothctl event stream and dispatches desktop notifications:
- Device connected (including battery percentage if available)
- Device disconnected
- Low battery alerts (<= 20% and <= 10%)
"""

import os
import re
import sys
import time
import signal
import subprocess

LOCK_FILE = f"/tmp/bluetooth_events_daemon_{os.getuid()}.pid"

# Cache of known devices:
# mac -> {"name": str, "icon": str, "battery": int|None, "connected": bool, "low_alert_level": int}
devices = {}

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
            # Check if process is still alive
            os.kill(old_pid, 0)
            # If alive, exit cleanly
            sys.exit(0)
        except (OSError, ValueError):
            pass
    try:
        with open(LOCK_FILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass

def get_symbolic_icon(icon_type, event="connected"):
    if event == "disconnected":
        return "bluetooth-disabled-symbolic"
    if event == "low_battery":
        return "battery-caution-symbolic"

    icon_lower = (icon_type or "").lower()
    if any(k in icon_lower for k in ["headset", "headphone", "audio"]):
        return "audio-headphones-symbolic"
    if "mouse" in icon_lower:
        return "input-mouse-symbolic"
    if "keyboard" in icon_lower:
        return "input-keyboard-symbolic"
    if any(k in icon_lower for k in ["gaming", "gamepad", "joystick"]):
        return "input-gaming-symbolic"
    if "phone" in icon_lower:
        return "phone-symbolic"
    return "bluetooth-symbolic"

def send_notification(summary, body, icon="bluetooth-symbolic", urgency="normal"):
    try:
        subprocess.run([
            "notify-send",
            "-a", "Bluetooth",
            "-u", urgency,
            "-i", icon,
            summary,
            body
        ], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def fetch_device_info(mac):
    try:
        out = subprocess.check_output(
            ["bluetoothctl", "info", mac],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2.0
        )
        name = None
        icon = "bluetooth"
        battery = None
        connected = False

        for line in out.splitlines():
            line = line.strip()
            if line.startswith("Alias:"):
                name = line.split("Alias:", 1)[1].strip()
            elif line.startswith("Name:") and not name:
                name = line.split("Name:", 1)[1].strip()
            elif line.startswith("Icon:"):
                icon = line.split("Icon:", 1)[1].strip()
            elif line.startswith("Connected:"):
                connected = "yes" in line.lower()
            elif "Battery Percentage:" in line:
                m = re.search(r"\((\d+)\)", line)
                if m:
                    battery = int(m.group(1))

        return {
            "name": name or mac,
            "icon": icon,
            "battery": battery,
            "connected": connected,
            "low_alert_level": 100
        }
    except Exception:
        return {
            "name": mac,
            "icon": "bluetooth",
            "battery": None,
            "connected": False,
            "low_alert_level": 100
        }

def init_connected_devices():
    """Initializes existing connected devices on startup to avoid notification spam at boot."""
    try:
        out = subprocess.check_output(
            ["bluetoothctl", "devices", "Connected"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=3.0
        )
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0] == "Device":
                mac = parts[1]
                info = fetch_device_info(mac)
                info["connected"] = True
                devices[mac] = info
    except Exception:
        pass

def handle_connected(mac):
    # Short wait for GATT battery service discovery if applicable
    time.sleep(0.3)
    info = fetch_device_info(mac)
    info["connected"] = True
    devices[mac] = info

    name = info["name"]
    battery = info["battery"]
    icon = get_symbolic_icon(info["icon"], "connected")

    if battery is not None:
        body = f"{name} • {battery}%"
    else:
        body = name

    send_notification("Bluetooth Connected", body, icon, "normal")

def handle_disconnected(mac):
    info = devices.get(mac, {})
    name = info.get("name") or mac
    icon_type = info.get("icon", "bluetooth")
    devices[mac] = {**info, "connected": False, "low_alert_level": 100}

    icon = get_symbolic_icon(icon_type, "disconnected")
    send_notification("Bluetooth Disconnected", name, icon, "normal")

def handle_battery(mac, battery_level):
    if mac not in devices:
        devices[mac] = fetch_device_info(mac)

    dev = devices[mac]
    dev["battery"] = battery_level
    name = dev.get("name", mac)
    last_alert = dev.get("low_alert_level", 100)

    # Reset alert threshold if battery charged back above 25%
    if battery_level > 25:
        dev["low_alert_level"] = 100
        return

    # Critical alert at <= 10%
    if battery_level <= 10 and last_alert > 10:
        dev["low_alert_level"] = 10
        send_notification("Critical Battery", f"{name} ({battery_level}%)", "battery-caution-symbolic", "critical")
    # Low alert at <= 20%
    elif battery_level <= 20 and last_alert > 20:
        dev["low_alert_level"] = 20
        send_notification("Low Battery", f"{name} ({battery_level}%)", "battery-caution-symbolic", "normal")

def main():
    check_single_instance()
    init_connected_devices()

    while running:
        proc = None
        try:
            proc = subprocess.Popen(
                ["bluetoothctl"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1
            )

            for line in proc.stdout:
                if not running:
                    break
                line = line.strip()
                if not line:
                    continue

                # Device Connected: yes / no
                m_conn = re.search(r"\[CHG\]\s+Device\s+([0-9A-Fa-f:]+)\s+Connected:\s+(yes|no)", line)
                if m_conn:
                    mac, state = m_conn.group(1), m_conn.group(2)
                    if state == "yes":
                        # Only notify if state genuinely changed
                        prev_state = devices.get(mac, {}).get("connected", False)
                        if not prev_state:
                            handle_connected(mac)
                    else:
                        prev_state = devices.get(mac, {}).get("connected", True)
                        if prev_state:
                            handle_disconnected(mac)
                    continue

                # Battery Percentage update
                m_bat = re.search(r"\[CHG\]\s+Device\s+([0-9A-Fa-f:]+)\s+Battery Percentage:\s+.*\((\d+)\)", line)
                if m_bat:
                    mac, pct_str = m_bat.group(1), m_bat.group(2)
                    handle_battery(mac, int(pct_str))
                    continue

                # Name or Alias change
                m_alias = re.search(r"\[CHG\]\s+Device\s+([0-9A-Fa-f:]+)\s+Alias:\s+(.*)", line)
                if m_alias:
                    mac, alias = m_alias.group(1), m_alias.group(2).strip()
                    if mac in devices:
                        devices[mac]["name"] = alias

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

    # Cleanup
    if os.path.exists(LOCK_FILE):
        try:
            os.remove(LOCK_FILE)
        except Exception:
            pass

if __name__ == "__main__":
    main()
