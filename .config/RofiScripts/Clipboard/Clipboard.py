#!/usr/bin/env python3
"""
QML-based Dual-Column Clipboard Manager for Hyprland & cliphist.
- Column 1: Image thumbnails with dimension labels.
- Column 2: Text cards with chronological #rank, elided preview and "Последнее" badge.
- Keyboard navigation (Left/Right to switch columns, Up/Down to navigate, Enter to copy, Esc to close).
- Real-time search filtering.
- Dynamic Matugen colors integration.
"""

import os
import re
import sys
import subprocess
import concurrent.futures
from pathlib import Path

# Setup QML import path for QtDeclarative if not set
NIX_QML_PATH = "/nix/store/3vd002px7rdr8cmr1wxh3628fpkrbhg2-qtdeclarative-6.11.1/lib/qt-6/qml"
if os.path.exists(NIX_QML_PATH):
    curr = os.environ.get("QML2_IMPORT_PATH", "")
    if NIX_QML_PATH not in curr:
        os.environ["QML2_IMPORT_PATH"] = f"{NIX_QML_PATH}:{curr}" if curr else NIX_QML_PATH

from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot, QUrl
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

HOME = Path.home()
SHOTS_DIR = HOME / "Pictures/Screenshots"
META_CACHE_FILE = HOME / ".cache/cliphist_meta.json"
THUMB_DIR = Path(f"/tmp/cliphist-thumbs-{os.getuid()}")
THUMB_DIR.mkdir(parents=True, exist_ok=True)
RE_BIN = re.compile(r"^\[\[ binary data (\S+ \S+) (\w+) (\d+x\d+) \]\]$")


def get_matugen_colors():
    """Reads colors from generated quickshell colors or provides sleek dark defaults."""
    colors = {
        "primary": "#b6ccba",
        "onPrimary": "#223428",
        "primaryContainer": "#384b3e",
        "surface": "#131412",
        "onSurface": "#e4e2e0",
        "surfaceVariant": "#434843",
        "onSurfaceVariant": "#c3c8c1",
        "outline": "#8d928c",
        "outlineVariant": "#2d302a",
        "surfaceContainer": "#1f201f",
        "surfaceContainerHigh": "#292a29",
        "surfaceContainerLowest": "#141513",
        "badgeBg": "#254566",
        "badgeFg": "#c6e2ff",
    }
    qs_colors = HOME / ".config/quickshell/overview/common/Appearance.colors.qml"
    if qs_colors.exists():
        try:
            content = qs_colors.read_text(encoding="utf-8")
            for line in content.splitlines():
                line = line.strip()
                if line.startswith("property color m3primary:"):
                    colors["primary"] = line.split('"')[1]
                elif line.startswith("property color m3onPrimary:"):
                    colors["onPrimary"] = line.split('"')[1]
                elif line.startswith("property color m3surface:"):
                    colors["surface"] = line.split('"')[1]
                elif line.startswith("property color m3onSurface:"):
                    colors["onSurface"] = line.split('"')[1]
                elif line.startswith("property color m3surfaceVariant:"):
                    colors["surfaceVariant"] = line.split('"')[1]
                elif line.startswith("property color m3onSurfaceVariant:"):
                    colors["onSurfaceVariant"] = line.split('"')[1]
                elif line.startswith("property color m3outline:"):
                    colors["outline"] = line.split('"')[1]
                elif line.startswith("property color m3outlineVariant:"):
                    colors["outlineVariant"] = line.split('"')[1]
                elif line.startswith("property color m3surfaceContainerLowest:"):
                    colors["surfaceContainerLowest"] = line.split('"')[1]
                elif line.startswith("property color m3surfaceContainer:"):
                    colors["surfaceContainer"] = line.split('"')[1]
                elif line.startswith("property color m3surfaceContainerHigh:"):
                    colors["surfaceContainerHigh"] = line.split('"')[1]
        except Exception:
            pass
    return colors


MONTHS = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


def format_section_date(dt, now):
    diff = (now.date() - dt.date()).days
    mon = MONTHS[dt.month]
    if diff == 0:
        return f"Today · {dt.day} {mon}"
    elif diff == 1:
        return f"Yesterday · {dt.day} {mon}"
    elif dt.year == now.year:
        return f"{dt.day} {mon}"
    else:
        return f"{dt.day} {mon} {dt.year}"


class ClipboardBackend(QObject):
    dataLoaded = pyqtSignal(list, list, int, int)
    filterCompleted = pyqtSignal(list, list)

    def __init__(self, app):
        super().__init__()
        self.app = app
        self.all_images = []
        self.all_texts = []
        self.meta_cache = self._load_meta_cache()
        self.size_to_dt = self._index_screenshots()
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=8)

    def _load_meta_cache(self):
        if META_CACHE_FILE.exists():
            try:
                import json
                return json.loads(META_CACHE_FILE.read_text(encoding="utf-8"))
            except Exception:
                return {}
        return {}

    def _save_meta_cache(self):
        try:
            import json
            META_CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
            META_CACHE_FILE.write_text(json.dumps(self.meta_cache, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception:
            pass

    def _index_screenshots(self):
        size_map = {}
        if SHOTS_DIR.exists():
            try:
                for f in sorted(SHOTS_DIR.glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True):
                    m = re.match(r"(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})", f.stem)
                    if m:
                        sz = f.stat().st_size
                        if sz not in size_map:
                            size_map[sz] = " ".join(m.groups())
            except Exception:
                pass
        return size_map

    def decode_and_get_dt(self, cid):
        dest = THUMB_DIR / f"{cid}.png"
        if not dest.exists():
            try:
                proc = subprocess.run(
                    ["cliphist", "decode", str(cid)],
                    capture_output=True,
                    check=True
                )
                dest.write_bytes(proc.stdout)
            except Exception:
                return ""

        cid_str = str(cid)
        if cid_str in self.meta_cache:
            return self.meta_cache[cid_str]

        dt = ""
        try:
            sz = dest.stat().st_size
            dt = self.size_to_dt.get(sz, "")
            if not dt:
                from datetime import datetime
                mtime = dest.stat().st_mtime
                dt = datetime.fromtimestamp(mtime).strftime("%Y %m %d %H %M")
        except Exception:
            pass

        if dt:
            self.meta_cache[cid_str] = dt
        return dt

    def load_history(self):
        from datetime import datetime, timedelta
        now = datetime.now()

        try:
            p = subprocess.run(["cliphist", "list"], capture_output=True, text=True, check=True)
            lines = p.stdout.strip().splitlines()
        except Exception:
            lines = []

        images_raw = []
        texts_raw = []
        img_rank = 0
        txt_rank = 0

        for line in lines:
            parts = line.split("\t", 1)
            if len(parts) != 2:
                continue
            cid, content = parts
            m = RE_BIN.match(content)
            if m:
                img_rank += 1
                size, ext, dims = m.groups()
                images_raw.append((img_rank, cid, size, ext, dims, line))
            else:
                txt_rank += 1
                clean = " ".join(content.split())
                texts_raw.append((txt_rank, cid, clean, line))

        # 1. Resolve dates & thumbnails for images in parallel
        cids_img = [item[1] for item in images_raw]
        dt_results = list(self.executor.map(self.decode_and_get_dt, cids_img))

        # 2. Build anchor map from known image timestamps
        anchors = {}
        for (rank, cid, size, ext, dims, line), dt_str in zip(images_raw, dt_results):
            if dt_str:
                try:
                    anchors[int(cid)] = datetime.strptime(dt_str, "%Y %m %d %H %M")
                except Exception:
                    pass

        sorted_anchor_cids = sorted(anchors.keys())

        def resolve_text_dt(cid_int):
            cid_str = str(cid_int)
            if cid_str in self.meta_cache:
                try:
                    return datetime.strptime(self.meta_cache[cid_str], "%Y %m %d %H %M")
                except Exception:
                    pass

            # Interpolate between surrounding anchors
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
                    self.meta_cache[cid_str] = interp_dt.strftime("%Y %m %d %H %M")
                    return interp_dt
                elif prev_c is not None:
                    p_dt = anchors[prev_c]
                    self.meta_cache[cid_str] = p_dt.strftime("%Y %m %d %H %M")
                    return p_dt
                elif next_c is not None:
                    n_dt = anchors[next_c]
                    self.meta_cache[cid_str] = n_dt.strftime("%Y %m %d %H %M")
                    return n_dt

            self.meta_cache[cid_str] = now.strftime("%Y %m %d %H %M")
            return now

        # 3. Format texts
        texts = []
        for rank, cid, clean, line in texts_raw:
            try:
                cid_int = int(cid)
            except Exception:
                cid_int = 0
            t_dt = resolve_text_dt(cid_int)
            dt_space = t_dt.strftime("%Y %m %d %H %M")
            time_str = t_dt.strftime("%H:%M")
            sec_date = format_section_date(t_dt, now)
            disp_dt = t_dt.strftime("%Y-%m-%d %H:%M")

            texts.append({
                "cid": cid,
                "rank": rank,
                "text": clean,
                "title": f"#{rank}  {clean}",
                "time_str": time_str,
                "section_date": sec_date,
                "date_time": dt_space,
                "display_dt": disp_dt,
                "search": f"#{rank} {rank} {clean} {dt_space} {time_str}".lower(),
                "raw_line": line
            })

        # 4. Format images
        images = []
        for (rank, cid, size, ext, dims, line), dt_str in zip(images_raw, dt_results):
            thumb_path = str(THUMB_DIR / f"{cid}.png")
            try:
                img_dt = datetime.strptime(dt_str, "%Y %m %d %H %M")
                disp_dt = img_dt.strftime("%Y-%m-%d %H:%M")
            except Exception:
                disp_dt = ""
            images.append({
                "cid": cid,
                "rank": rank,
                "dims": dims,
                "size": size,
                "date_time": dt_str,
                "display_dt": disp_dt,
                "title": f"#{rank} Image {dims}",
                "search": f"#{rank} {rank} image {dims} {dt_str}".lower(),
                "thumb_url": f"file://{thumb_path}",
                "raw_line": line
            })

        self._save_meta_cache()
        self.all_images = images
        self.all_texts = texts
        self.last_query = ""
        self.dataLoaded.emit(images, texts, len(images), len(texts))

    @pyqtSlot(str)
    def search(self, query):
        self.last_query = query.strip().lower()
        if not self.last_query:
            self.filterCompleted.emit(self.all_images, self.all_texts)
            return

        filtered_texts = [
            t for t in self.all_texts
            if self.last_query in t["search"] or self.last_query in t["text"].lower()
        ]
        filtered_images = [
            img for img in self.all_images
            if self.last_query in img["search"] or self.last_query in img["title"].lower()
        ]
        self.filterCompleted.emit(filtered_images, filtered_texts)

    @pyqtSlot(str, bool)
    def copyItem(self, cid, is_image):
        try:
            cmd = f"cliphist decode {cid} | wl-copy"
            if is_image:
                cmd += " --type image/png"
            subprocess.run(cmd, shell=True, check=True)
        except Exception as e:
            print(f"Error copying: {e}", file=sys.stderr)
        self.app.quit()

    @pyqtSlot(str, bool)
    def deleteItem(self, cid, is_image):
        target = None
        if is_image:
            for it in self.all_images:
                if str(it["cid"]) == str(cid):
                    target = it
                    self.all_images.remove(it)
                    break
            thumb = THUMB_DIR / f"{cid}.png"
            if thumb.exists():
                try:
                    thumb.unlink()
                except Exception:
                    pass
            if str(cid) in self.meta_cache:
                del self.meta_cache[str(cid)]
                self._save_meta_cache()
        else:
            for it in self.all_texts:
                if str(it["cid"]) == str(cid):
                    target = it
                    self.all_texts.remove(it)
                    break

        if target and "raw_line" in target:
            try:
                proc = subprocess.Popen(["cliphist", "delete"], stdin=subprocess.PIPE, text=True)
                proc.communicate(input=target["raw_line"] + "\n")
            except Exception as e:
                print(f"Error deleting cliphist entry: {e}", file=sys.stderr)

        # Re-apply current search filter
        self.search(self.last_query)

    @pyqtSlot()
    def openMenu(self):
        launcher = HOME / ".config/RofiScripts/Launcher/Tools.sh"
        if launcher.exists():
            subprocess.Popen([str(launcher)])
        self.app.quit()

    @pyqtSlot()
    def close(self):
        self.app.quit()


def main():
    # Kill any existing instance to act as a toggle
    my_pid = os.getpid()
    subprocess.run(
        f"pgrep -f 'Clipboard.py' | grep -v '^{my_pid}$' | xargs -r kill -9",
        shell=True
    )

    app = QGuiApplication(sys.argv)
    app.setApplicationName("org.hypr.qml-clipboard")
    app.setDesktopFileName("org.hypr.qml-clipboard")

    engine = QQmlApplicationEngine()
    import glob
    qml_paths = ["/nix/store/3vd002px7rdr8cmr1wxh3628fpkrbhg2-qtdeclarative-6.11.1/lib/qt-6/qml"]
    for p in glob.glob("/nix/store/*-qtdeclarative-*/lib/qt-6/qml"):
        if p not in qml_paths:
            qml_paths.append(p)
    for p in qml_paths:
        if os.path.isdir(p):
            engine.addImportPath(p)

    backend = ClipboardBackend(app)
    colors = get_matugen_colors()

    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("themeColors", colors)

    qml_file = Path(__file__).parent / "Clipboard.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(1)

    # Initial async load of data
    backend.load_history()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
