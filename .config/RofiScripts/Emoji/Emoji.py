#!/usr/bin/env python3
"""
QML-based Categorized Emoji Picker for Hyprland.
- Full Unicode emoji database with English descriptions and search.
- Category pills: ★ Частые, 😀 Смайлы, 🧑 Люди, 🐱 Животные, 🌸 Природа,
  🍔 Еда, 🚗 Места, ⚽ Досуг, 💡 Предметы, ✅ Символы, 🏳️ Флаги, 🗂️ Все.
- Tab/Shift+Tab to cycle categories, arrow keys ↑ ↓ ← → to navigate the grid.
- Enter to copy & type into active window, Esc to close.
- Dynamic Matugen color palette integration.
"""

import os
import sys
import json
import shutil
import subprocess
from pathlib import Path

# Setup QML import path for QtDeclarative if not set
NIX_QML_PATH = "/nix/store/3vd002px7rdr8cmr1wxh3628fpkrbhg2-qtdeclarative-6.11.1/lib/qt-6/qml"
if os.path.exists(NIX_QML_PATH):
    curr = os.environ.get("QML2_IMPORT_PATH", "")
    if NIX_QML_PATH not in curr:
        os.environ["QML2_IMPORT_PATH"] = f"{NIX_QML_PATH}:{curr}" if curr else NIX_QML_PATH

from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

HOME = Path.home()
CACHE_DIR = HOME / ".cache"
RECENT_FILE = CACHE_DIR / "emoji_recent.json"
DATA_FILE = Path(__file__).parent / "emojis_data.json"

DEFAULT_POPULAR = [
    {"char": "😎", "name": "smiling face with sunglasses", "search": "smiling face with sunglasses cool sunglasses"},
    {"char": "👀", "name": "eyes", "search": "eyes look peek see"},
    {"char": "🙂", "name": "slightly smiling face", "search": "slightly smiling face smile"},
    {"char": "👍", "name": "thumbs up", "search": "thumbs up like ok yes"},
    {"char": "👎", "name": "thumbs down", "search": "thumbs down dislike no"},
    {"char": "❤️", "name": "red heart", "search": "red heart love"},
    {"char": "💩", "name": "pile of poo", "search": "pile of poo poop turd"},
    {"char": "😁", "name": "beaming face with smiling eyes", "search": "beaming face with smiling eyes grin"},
    {"char": "🤣", "name": "rolling on the floor laughing", "search": "rolling on the floor laughing rofl lol"},
    {"char": "🤡", "name": "clown face", "search": "clown face clown circus"},
    {"char": "🤮", "name": "face vomiting", "search": "face vomiting sick barf puke"},
    {"char": "🌚", "name": "new moon face", "search": "new moon face moon creepy smug"},
    {"char": "🔥", "name": "fire", "search": "fire lit hot flame"},
    {"char": "🎉", "name": "party popper", "search": "party popper tada celebration party"},
    {"char": "✨", "name": "sparkles", "search": "sparkles magic shine star"},
    {"char": "🚀", "name": "rocket", "search": "rocket launch fly space fast"},
    {"char": "💯", "name": "hundred points", "search": "hundred points 100 score perfect"},
    {"char": "💀", "name": "skull", "search": "skull dead death skeleton"},
    {"char": "🗿", "name": "moai", "search": "moai statue stone chad sigma"},
    {"char": "🥺", "name": "pleading face", "search": "pleading face puppy eyes please cute"},
    {"char": "🤝", "name": "handshake", "search": "handshake deal agreement agree"},
    {"char": "🫡", "name": "saluting face", "search": "saluting face salute respect yes sir"},
    {"char": "🤔", "name": "thinking face", "search": "thinking face think hmm consider"},
    {"char": "🫠", "name": "melting face", "search": "melting face melt heat disappear sarcastic"},
    {"char": "🥳", "name": "partying face", "search": "partying face party celebrate hat horn"},
    {"char": "😈", "name": "smiling face with horns", "search": "smiling face with horns evil devil naughty"},
    {"char": "🤖", "name": "robot", "search": "robot bot ai android cyborg"},
    {"char": "👾", "name": "alien monster", "search": "alien monster space invader retro game"},
    {"char": "👻", "name": "ghost", "search": "ghost spooky halloween boo"}
]

CATEGORIES = [
    {"id": "frequent", "name": "★ Recent"},
    {"id": "smileys", "name": "😀 Faces"},
    {"id": "people", "name": "🧑 People"},
    {"id": "animals", "name": "🐱 Animals"},
    {"id": "nature", "name": "🌸 Nature"},
    {"id": "food", "name": "🍔 Food"},
    {"id": "places", "name": "🚗 Places"},
    {"id": "activities", "name": "⚽ Activities"},
    {"id": "objects", "name": "💡 Objects"},
    {"id": "symbols", "name": "✅ Symbols"},
    {"id": "flags", "name": "🏳️ Flags"},
    {"id": "all", "name": "🗂️ All"}
]


def get_matugen_colors():
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


class EmojiBackend(QObject):
    categoriesLoaded = pyqtSignal(list)
    emojisLoaded = pyqtSignal(list)

    def __init__(self, app):
        super().__init__()
        self.app = app
        self.all_emojis_by_cat = {}
        self.flat_all = []
        self.recent_emojis = []
        self.current_cat = "frequent"
        self._load_data()

    def _load_data(self):
        # Load recent
        if RECENT_FILE.exists():
            try:
                self.recent_emojis = json.loads(RECENT_FILE.read_text(encoding="utf-8"))
            except Exception:
                self.recent_emojis = list(DEFAULT_POPULAR)
        else:
            self.recent_emojis = list(DEFAULT_POPULAR)

        # Load main data
        if DATA_FILE.exists():
            try:
                self.all_emojis_by_cat = json.loads(DATA_FILE.read_text(encoding="utf-8"))
            except Exception:
                self.all_emojis_by_cat = {}

        # Build flat all
        seen = set()
        flat = []
        for cat, items in self.all_emojis_by_cat.items():
            for it in items:
                if it["char"] not in seen:
                    seen.add(it["char"])
                    flat.append(it)
        self.flat_all = flat

    def init_ui(self):
        self.categoriesLoaded.emit(CATEGORIES)
        self.selectCategory("frequent")

    @pyqtSlot(str)
    def selectCategory(self, cat_id):
        self.current_cat = cat_id
        if cat_id == "frequent":
            items = self.recent_emojis
        elif cat_id == "all":
            items = self.flat_all
        else:
            items = self.all_emojis_by_cat.get(cat_id, [])
        self.emojisLoaded.emit(items)

    @pyqtSlot(str, str)
    def search(self, query, current_cat_id):
        q = query.strip().lower()
        if not q:
            self.selectCategory(current_cat_id)
            return

        # When searching, search across all emojis for full coverage
        results = [e for e in self.flat_all if q in e["search"]]
        self.emojisLoaded.emit(results)

    @pyqtSlot(str, str)
    def insertEmoji(self, emoji_char, emoji_name):
        # Update recent
        new_recent = [{"char": emoji_char, "name": emoji_name, "search": f"{emoji_name} {emoji_char}".lower()}]
        for it in self.recent_emojis:
            if it["char"] != emoji_char:
                new_recent.append(it)
            if len(new_recent) >= 60:
                break
        self.recent_emojis = new_recent
        try:
            RECENT_FILE.parent.mkdir(parents=True, exist_ok=True)
            RECENT_FILE.write_text(json.dumps(new_recent, ensure_ascii=False, indent=2), encoding="utf-8")
        except Exception:
            pass

        # Copy to clipboard
        subprocess.run(["wl-copy", emoji_char], check=False)

        # Try to type into active window
        wtype_bin = shutil.which("wtype") or "/nix/store/2ljrpd04hhwary2fir7183c4inyx1y9a-wtype-0.4/bin/wtype"
        if os.path.exists(wtype_bin):
            subprocess.Popen(
                f"sleep 0.08 && {wtype_bin} '{emoji_char}'",
                shell=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

        self.app.quit()

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
    my_pid = os.getpid()
    subprocess.run(
        f"pgrep -f 'Emoji.py' | grep -v '^{my_pid}$' | xargs -r kill -9",
        shell=True
    )

    app = QGuiApplication(sys.argv)
    app.setApplicationName("org.hypr.qml-emoji")
    app.setDesktopFileName("org.hypr.qml-emoji")

    engine = QQmlApplicationEngine()
    import glob
    qml_paths = ["/nix/store/3vd002px7rdr8cmr1wxh3628fpkrbhg2-qtdeclarative-6.11.1/lib/qt-6/qml"]
    for p in glob.glob("/nix/store/*-qtdeclarative-*/lib/qt-6/qml"):
        if p not in qml_paths:
            qml_paths.append(p)
    for p in qml_paths:
        if os.path.isdir(p):
            engine.addImportPath(p)

    backend = EmojiBackend(app)
    colors = get_matugen_colors()

    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("themeColors", colors)

    qml_file = Path(__file__).parent / "Emoji.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(1)

    backend.init_ui()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
