#!/usr/bin/env python3
"""
Clipboard History Grid Menu for Rofi & cliphist.
- Dense 3x2 grid of cards with minimal padding.
- Direct thumbnail previews for screenshots/images.
- Solid multi-line text blocks (SVG) for copied texts and code snippets.
- Full keyboard navigation and instant search.
"""

import os
import re
import sys
import html
import subprocess
import concurrent.futures

HOME = os.path.expanduser("~")
THUMB_DIR = f"/tmp/cliphist-thumbs-{os.getuid()}-v8"
ROFI_CONFIG = os.path.join(HOME, ".config/RofiScripts/Clipboard/CB.rasi")

RE_BIN = re.compile(r"^\[\[ binary data (\S+ \S+) (\w+) (\d+x\d+) \]\]$")

def generate_text_card(cid, content):
    path = os.path.join(THUMB_DIR, f"{cid}.svg")
    if os.path.exists(path):
        return path

    raw_lines = content.strip().splitlines()
    clean_lines = [l for l in raw_lines if l.strip()]

    font_size = 14
    line_height = 20
    max_chars = 36
    max_lines = 8

    card_lines = []
    for l in clean_lines:
        while len(l) > max_chars and len(card_lines) < max_lines:
            card_lines.append(l[:max_chars])
            l = l[max_chars:]
        if len(card_lines) < max_lines:
            card_lines.append(l)
        if len(card_lines) >= max_lines:
            break

    if not card_lines:
        card_lines = ["(empty)"]

    spans = []
    y = line_height - 2
    for l in card_lines:
        esc = html.escape(l)
        spans.append(f'<text x="8" y="{y}" fill="#e4e2e0" font-family="JetBrainsMono Nerd Font Propo, monospace" font-size="{font_size}">{esc}</text>')
        y += line_height

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180">
  {''.join(spans)}
</svg>'''
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write(svg)
    except Exception:
        pass
    return path

def fetch_thumb(item):
    cid, thumb_path = item
    try:
        p = subprocess.run(["cliphist", "decode", cid], stdout=subprocess.PIPE, timeout=3)
        if p.returncode == 0 and p.stdout:
            with open(thumb_path, "wb") as f:
                f.write(p.stdout)
    except Exception:
        pass

def load_cliphist_items():
    os.makedirs(THUMB_DIR, exist_ok=True)
    try:
        raw = subprocess.check_output(["cliphist", "list"], timeout=5).decode("utf-8", "replace")
    except Exception:
        return []

    lines = [l for l in raw.strip().split("\n") if l]
    items = []
    uncached_images = []

    for line in lines:
        parts = line.split("\t", 1)
        cid = parts[0]
        content = parts[1] if len(parts) > 1 else ""

        m = RE_BIN.match(content)
        if m:
            size_str, fmt, res = m.groups()
            thumb = os.path.join(THUMB_DIR, f"{cid}.png")
            if not os.path.exists(thumb):
                uncached_images.append((cid, thumb))
            meta = f"image screenshot {res} {size_str} картинка фото"
            items.append({
                "id": cid,
                "label": f"Image {res}",
                "icon": thumb,
                "meta": meta,
                "is_image": True,
            })
        else:
            flat = content.replace("\n", " ").replace("\r", " ").replace("\0", "").replace("\x1f", " ")
            card_icon = generate_text_card(cid, content)
            items.append({
                "id": cid,
                "label": flat,
                "icon": card_icon,
                "meta": flat,
                "is_image": False,
            })

    # Decode any missing image thumbnails in parallel
    if uncached_images:
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
            list(ex.map(fetch_thumb, uncached_images))

    return items

def run_menu(selected_row=0):
    while True:
        items = load_cliphist_items()
        if not items:
            break

        menu_entries = []
        for item in items:
            line = f"{item['label']}\0icon\x1f{item['icon']}\x1fmeta\x1f{item['meta']}"
            menu_entries.append(line)

        payload = "\n".join(menu_entries).encode("utf-8")

        rofi_cmd = [
            "rofi",
            "-dmenu",
            "-i",
            "-format", "i",
            "-selected-row", str(selected_row if selected_row < len(menu_entries) else 0),
            "-config", ROFI_CONFIG,
            "-kb-accept-entry", "Control+m,Return,KP_Enter",
        ]

        try:
            proc = subprocess.Popen(
                rofi_cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
            )
            out, _ = proc.communicate(input=payload)
            rc = proc.returncode
        except Exception:
            break

        # Normal Enter / Selection
        if rc == 0:
            raw_out = out.decode("utf-8", "replace").strip()
            if not raw_out or not raw_out.isdigit():
                break
            idx = int(raw_out)
            if idx < len(items):
                cid = items[idx]["id"]
                try:
                    dec_p = subprocess.Popen(["cliphist", "decode", cid], stdout=subprocess.PIPE)
                    subprocess.run(["wl-copy"], stdin=dec_p.stdout, check=True)
                    dec_p.wait()
                except Exception:
                    pass
                break
            break

        # Esc or cancelled
        break

if __name__ == "__main__":
    run_menu()
