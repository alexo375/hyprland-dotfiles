#!/usr/bin/env python3
"""
Lightweight metadata generator for cliphist items.
Matches image items to ~/Pictures/Screenshots by file size and interpolates text item timestamps.
"""

import json
import os
import re
import subprocess
from pathlib import Path
from datetime import datetime, timedelta

def sync_metadata():
    home = Path.home()
    shots_dir = home / "Pictures/Screenshots"
    meta_file = home / ".cache/cliphist_meta.json"
    thumb_dir = Path(f"/tmp/cliphist-thumbs-{os.getuid()}")
    thumb_dir.mkdir(parents=True, exist_ok=True)

    meta_cache = {}
    if meta_file.exists():
        try:
            meta_cache = json.loads(meta_file.read_text("utf-8"))
        except Exception:
            meta_cache = {}

    size_map = {}
    if shots_dir.exists():
        try:
            for f in sorted(shots_dir.glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True)[:200]:
                m = re.match(r"(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})", f.stem)
                if m:
                    sz = f.stat().st_size
                    if sz not in size_map:
                        size_map[sz] = " ".join(m.groups())
        except Exception:
            pass

    try:
        p = subprocess.run(["cliphist", "list"], capture_output=True, text=True, timeout=2.0)
        lines = p.stdout.splitlines()
    except Exception:
        return

    images_raw = []
    texts_raw = []
    for line in lines:
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        cid, content = parts
        if content.startswith("[[ binary data"):
            images_raw.append(cid)
        else:
            texts_raw.append(cid)

    # 1. Resolve top images
    anchors = {}
    for cid in images_raw[:40]:
        cid_str = str(cid)
        dt_str = meta_cache.get(cid_str)
        thumb_path = thumb_dir / f"{cid}.png"

        if not dt_str:
            if not thumb_path.exists():
                try:
                    dec = subprocess.run(["cliphist", "decode", str(cid)], capture_output=True, timeout=1.0)
                    thumb_path.write_bytes(dec.stdout)
                except Exception:
                    pass

            if thumb_path.exists():
                try:
                    sz = thumb_path.stat().st_size
                    dt_str = size_map.get(sz)
                    if not dt_str:
                        mtime = thumb_path.stat().st_mtime
                        dt_str = datetime.fromtimestamp(mtime).strftime("%Y %m %d %H %M")
                    if dt_str:
                        meta_cache[cid_str] = dt_str
                except Exception:
                    pass

        if dt_str:
            try:
                anchors[int(cid)] = datetime.strptime(dt_str, "%Y %m %d %H %M")
            except Exception:
                pass

    sorted_anchor_cids = sorted(anchors.keys())
    now = datetime.now()

    # 2. Interpolate timestamps for text items
    for cid in texts_raw:
        cid_str = str(cid)
        if cid_str in meta_cache:
            continue
        try:
            cid_int = int(cid)
        except Exception:
            continue

        if sorted_anchor_cids:
            prev_c = None
            next_c = None
            for a in sorted_anchor_cids:
                if a < cid_int:
                    prev_c = a
                elif a > cid_int and next_c is None:
                    next_c = a
                    break

            if prev_c is not None and next_c is not None:
                p_dt = anchors[prev_c]
                n_dt = anchors[next_c]
                ratio = (cid_int - prev_c) / (next_c - prev_c)
                sec_delta = (n_dt - p_dt).total_seconds() * ratio
                interp_dt = p_dt + timedelta(seconds=sec_delta)
                meta_cache[cid_str] = interp_dt.strftime("%Y %m %d %H %M")
            elif prev_c is not None:
                meta_cache[cid_str] = anchors[prev_c].strftime("%Y %m %d %H %M")
            elif next_c is not None:
                meta_cache[cid_str] = anchors[next_c].strftime("%Y %m %d %H %M")
        else:
            meta_cache[cid_str] = now.strftime("%Y %m %d %H %M")

    try:
        meta_file.parent.mkdir(parents=True, exist_ok=True)
        meta_file.write_text(json.dumps(meta_cache, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception:
        pass

if __name__ == "__main__":
    sync_metadata()
