#!/usr/bin/env python3
import os
import sys
import time
import json
import glob
import html
import signal
import threading
import subprocess

SHM_NOTIFY_FILE = "/dev/shm/waybar_notification.json"
SHM_ACTIVE_FILE = "/dev/shm/waybar_notification_active"
NOTIFY_DURATION_SECONDS = 6.0

def is_dnd_active():
    try:
        res = subprocess.run(["swaync-client", "-D"], capture_output=True, text=True, timeout=0.2)
        return res.stdout.strip() == "true"
    except Exception:
        return False

wake_event = threading.Event()
active_notification = None
expires_at = 0.0

prev_cpu_idle = 0.0
prev_cpu_total = 0.0

def get_cpu():
    global prev_cpu_idle, prev_cpu_total
    try:
        with open("/proc/stat", "r") as f:
            line = f.readline()
        fields = [float(x) for x in line.split()[1:]]
        idle = fields[3] + fields[4]
        total = sum(fields)
        if prev_cpu_total == 0.0:
            prev_cpu_idle = idle
            prev_cpu_total = total
            return 0
        diff_idle = idle - prev_cpu_idle
        diff_total = total - prev_cpu_total
        prev_cpu_idle = idle
        prev_cpu_total = total
        if diff_total > 0:
            usage = int(100.0 * (1.0 - (diff_idle / diff_total)))
            return max(0, min(100, usage))
    except Exception:
        pass
    return 0

def get_temp():
    paths = (
        glob.glob("/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp*_label") +
        glob.glob("/sys/class/hwmon/hwmon*/temp*_label")
    )
    for label in paths:
        try:
            with open(label, "r") as f:
                if f.read().strip() == "Package id 0":
                    inp = label.replace("_label", "_input")
                    with open(inp, "r") as fi:
                        val = fi.read().strip()
                        if val.isdigit():
                            return int(int(val) / 1000)
        except Exception:
            pass
    # Fallback to any temp1_input
    for inp in glob.glob("/sys/class/hwmon/hwmon*/temp1_input"):
        try:
            with open(inp, "r") as fi:
                val = fi.read().strip()
                if val.isdigit():
                    return int(int(val) / 1000)
        except Exception:
            pass
    return 40

def get_fan():
    fans = []
    for f in glob.glob("/sys/class/hwmon/hwmon*/fan*_input"):
        try:
            with open(f, "r") as fi:
                val = fi.read().strip()
                if val.isdigit():
                    fans.append(int(val))
        except Exception:
            pass
    if not fans:
        return "idle"
    avg = sum(fans) // len(fans)
    return f"{avg}RPM" if avg > 0 else "idle"

def get_ram():
    tot, avail = 0, 0
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    tot = int(line.split()[1])
                elif line.startswith("MemAvailable:"):
                    avail = int(line.split()[1])
        used = tot - avail
        return f"{used / 1048576:.1f}GiB", f"{tot / 1048576:.1f}GiB", int(used * 100 / tot)
    except Exception:
        return "N/A", "N/A", 0

def get_notification_icon(app, summary):
    app_lower = app.lower()
    sum_lower = summary.lower()
    combined = f"{app_lower} {sum_lower}"

    if any(k in combined for k in ["screenshot", "снимок", "screenrec", "grim", "hyprshot", "grimblast"]):
        return "󰄄"
    if any(k in combined for k in ["telegram", "chat"]):
        return "󰭻"
    if any(k in combined for k in ["discord", "vesktop"]):
        return "󰙯"
    if any(k in combined for k in ["firefox", "chrome", "chromium", "brave", "zen", "browser"]):
        return "󰈹"
    if any(k in combined for k in ["spotify", "music", "yandex", "player", "media"]):
        return "󰝚"
    if any(k in combined for k in ["nix", "pacman", "package", "update", "upgrade"]):
        return "󰏗"
    if any(k in combined for k in ["battery", "power", "charge"]):
        return "󰂎"
    if any(k in combined for k in ["bluetooth"]):
        return "󰂯"
    if any(k in combined for k in ["wifi", "network", "ethernet"]):
        return "󰖩"
    if any(k in combined for k in ["volume", "audio", "sound"]):
        return "󰕾"
    if any(k in combined for k in ["terminal", "kitty", "bash", "zsh", "fish", "alacritty"]):
        return "󰆍"
    return "󰂚"

def format_notification(noti):
    app = noti.get("app", "")
    summary = noti.get("summary", "")
    body = noti.get("body", "")
    urgency = noti.get("urgency", "Normal")

    if isinstance(body, str):
        body = body.replace("\\n", "\n").replace("\\r", "")
    if isinstance(summary, str):
        summary = summary.replace("\\n", " ").replace("\\r", "")

    if app == "osd":
        icon = noti.get("icon", "󰕾")
        val = noti.get("value", -1)
        safe_sum = html.escape(summary.strip())
        if val >= 0:
            filled = int(round((max(0, min(100, val)) / 100.0) * 10))
            empty = 10 - filled
            bar = "━" * filled + "─" * empty
            display_text = f"{icon}  <b>{safe_sum}</b>  <span alpha='65%'>[{bar}]</span>"
        else:
            display_text = f"{icon}  <b>{safe_sum}</b>"
        return {
            "text": display_text,
            "class": "notification",
            "tooltip": safe_sum
        }

    icon = get_notification_icon(app, summary)

    # For status bar, only use the first line of the body
    body_lines = [line.strip() for line in body.splitlines() if line.strip()]
    body_first = body_lines[0] if body_lines else ""

    safe_summary = html.escape(summary.strip())
    safe_body = html.escape(body_first)

    # Clean up redundant duplicate summary and body
    if safe_summary.lower() == safe_body.lower() or not safe_body:
        full_text = f"<b>{safe_summary}</b>" if safe_summary else "<b>Notification</b>"
    elif safe_summary.lower() == app.lower():
        full_text = f"<b>{safe_summary}</b>: {safe_body}"
    elif any(k in f"{app} {summary}".lower() for k in ["screenshot", "снимок"]):
        full_text = f"<b>Screenshot</b>: {safe_body}"
    elif safe_summary and safe_body:
        full_text = f"<b>{safe_summary}</b>: {safe_body}"
    elif safe_summary:
        full_text = f"<b>{safe_summary}</b>"
    else:
        full_text = safe_body

    # Truncate for bar width
    max_len = 46
    raw_preview = f"{summary}: {body_first}".strip(" :")
    if len(raw_preview) > max_len:
        if len(summary) >= max_len - 5:
            full_text = f"<b>{html.escape(summary[:max_len-5].rstrip())}…</b>"
        else:
            remain = max_len - len(summary) - 3
            full_text = f"<b>{safe_summary}</b>: {html.escape(body_first[:remain].rstrip())}…"

    display_text = f"{icon}  {full_text}"

    cls = "notification"
    if urgency.lower() == "critical":
        cls += " notification-critical"

    tooltip_lines = []
    if app:
        tooltip_lines.append(f"<b>{html.escape(app)}</b>")
    if summary and summary.lower() != app.lower():
        tooltip_lines.append(f"<b>{html.escape(summary)}</b>")
    if body:
        tooltip_lines.append(html.escape(body))
    tooltip_lines.append("")
    tooltip_lines.append("<i>Click: Notification Center | Right-click: Dismiss</i>")

    return {
        "text": display_text,
        "class": cls,
        "tooltip": "\n".join(tooltip_lines)
    }

def format_sysstats():
    cpu = get_cpu()
    temp = get_temp()
    fan = get_fan()
    ram_used, ram_tot, ram_pct = get_ram()

    text = f" {cpu}%   {temp}°C  󰈐 {fan}   {ram_used}"
    tooltip = (
        f"<b>System Status</b>\n"
        f"CPU Load: {cpu}%\n"
        f"Package Temp: {temp}°C\n"
        f"Fan Speed: {fan}\n"
        f"Memory: {ram_used} / {ram_tot} ({ram_pct}%)\n\n"
        f"<i>Click: System Monitor | Right-click: Notification Center</i>"
    )

    return {
        "text": text,
        "class": "sysstats",
        "tooltip": tooltip
    }

def handle_sigusr1(signum, frame):
    global active_notification, expires_at
    try:
        if os.path.exists(SHM_NOTIFY_FILE):
            with open(SHM_NOTIFY_FILE, "r") as f:
                data = json.load(f)
            # If DND is enabled and this is not an OSD notification, discard
            if data.get("app") != "osd" and is_dnd_active():
                active_notification = None
                expires_at = 0.0
                try:
                    if os.path.exists(SHM_ACTIVE_FILE):
                        os.remove(SHM_ACTIVE_FILE)
                except Exception:
                    pass
                wake_event.set()
                return

            active_notification = data
            duration = float(active_notification.get("duration", NOTIFY_DURATION_SECONDS))
            expires_at = time.time() + duration
            try:
                with open(SHM_ACTIVE_FILE, "w") as f:
                    f.write("1")
            except Exception:
                pass
    except Exception:
        pass
    wake_event.set()

def handle_sigusr2(signum, frame):
    global active_notification, expires_at
    active_notification = None
    expires_at = 0.0
    try:
        if os.path.exists(SHM_ACTIVE_FILE):
            os.remove(SHM_ACTIVE_FILE)
    except Exception:
        pass
    wake_event.set()

def handle_exit(signum, frame):
    try:
        if os.path.exists(SHM_ACTIVE_FILE):
            os.remove(SHM_ACTIVE_FILE)
    except Exception:
        pass
    sys.exit(0)

def main():
    signal.signal(signal.SIGUSR1, handle_sigusr1)
    signal.signal(signal.SIGUSR2, handle_sigusr2)
    signal.signal(signal.SIGTERM, handle_exit)
    signal.signal(signal.SIGINT, handle_exit)

    # Clean active flag on start
    try:
        if os.path.exists(SHM_ACTIVE_FILE):
            os.remove(SHM_ACTIVE_FILE)
    except Exception:
        pass

    # Initialize CPU counter
    get_cpu()

    global active_notification, expires_at

    while True:
        wake_event.clear()
        now = time.time()

        if active_notification is not None:
            # If DND was activated while a notification is displayed, clear it immediately
            if active_notification.get("app") != "osd" and is_dnd_active():
                active_notification = None
                expires_at = 0.0
                try:
                    if os.path.exists(SHM_ACTIVE_FILE):
                        os.remove(SHM_ACTIVE_FILE)
                except Exception:
                    pass
                payload = format_sysstats()
                timeout = 2.0
            elif now >= expires_at:
                active_notification = None
                expires_at = 0.0
                try:
                    if os.path.exists(SHM_ACTIVE_FILE):
                        os.remove(SHM_ACTIVE_FILE)
                except Exception:
                    pass
                payload = format_sysstats()
                timeout = 2.0
            else:
                payload = format_notification(active_notification)
                timeout = min(0.5, max(0.2, expires_at - now))
        else:
            payload = format_sysstats()
            timeout = 2.0

        try:
            print(json.dumps(payload), flush=True)
        except Exception:
            pass

        wake_event.wait(timeout)

if __name__ == "__main__":
    main()
