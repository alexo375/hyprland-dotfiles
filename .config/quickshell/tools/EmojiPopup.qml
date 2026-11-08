import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

PanelWindow {
    id: root
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:emoji"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var categories: [
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
    property int currentCategoryIndex: 0
    property var allEmojisByCat: ({})
    property var flatAll: []
    property var recentEmojis: []
    property var emojiList: []

    readonly property var defaultPopular: [
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

    function open() {
        root.visible = true;
        searchInput.text = "";
        selectTab(0);
        searchInput.forceActiveFocus();
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        if (root.visible) close();
        else open();
    }

    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: root.visible
        onCleared: () => {
            root.close();
        }
    }

    // Load full emoji dataset
    FileView {
        id: dataFile
        path: "/home/alex/hyprland-dotfiles/.config/quickshell/tools/emojis_data.json"
        onLoaded: {
            try {
                let data = JSON.parse(text());
                root.allEmojisByCat = data;

                let seen = new Set();
                let flat = [];
                for (let cat in data) {
                    for (let it of data[cat]) {
                        if (!seen.has(it.char)) {
                            seen.add(it.char);
                            flat.push(it);
                        }
                    }
                }
                root.flatAll = flat;
                if (root.currentCategoryIndex === 0 && root.recentEmojis.length === 0) {
                    selectTab(0);
                }
            } catch (e) {
                console.error("Error parsing emojis_data.json:", e);
            }
        }
    }

    // Load recent emojis
    FileView {
        id: recentFile
        path: "/home/alex/.cache/emoji_recent.json"
        onLoaded: {
            try {
                let rec = JSON.parse(text());
                if (Array.isArray(rec) && rec.length > 0) {
                    root.recentEmojis = rec;
                } else {
                    root.recentEmojis = root.defaultPopular;
                }
            } catch (e) {
                root.recentEmojis = root.defaultPopular;
            }
            if (root.currentCategoryIndex === 0) {
                root.emojiList = root.recentEmojis;
            }
        }
    }

    function selectTab(index) {
        if (index < 0 || index >= root.categories.length) return;
        root.currentCategoryIndex = index;
        let cat = root.categories[index];
        if (cat) {
            searchInput.text = "";
            if (cat.id === "frequent") {
                root.emojiList = root.recentEmojis.length > 0 ? root.recentEmojis : root.defaultPopular;
            } else if (cat.id === "all") {
                root.emojiList = root.flatAll;
            } else {
                root.emojiList = root.allEmojisByCat[cat.id] || [];
            }
            if (emojiGrid.count > 0) emojiGrid.currentIndex = 0;
        }

        let item = tabRepeater.itemAt(index);
        if (item && tabRow.width > tabScrollView.width) {
            let targetX = item.x - (tabScrollView.width - item.width) / 2;
            let maxScroll = tabRow.width - tabScrollView.width;
            let clampedX = Math.max(0, Math.min(targetX, maxScroll));
            tabScrollView.ScrollBar.horizontal.position = clampedX / tabRow.width;
        }
    }

    function search(query) {
        let q = (query || "").trim().toLowerCase();
        if (!q) {
            selectTab(root.currentCategoryIndex);
            return;
        }
        root.emojiList = root.flatAll.filter(e => e.search && e.search.includes(q));
        if (emojiGrid.count > 0) emojiGrid.currentIndex = 0;
    }

    function insertCurrent() {
        if (emojiGrid.count > 0 && emojiGrid.currentIndex >= 0 && emojiGrid.currentIndex < root.emojiList.length) {
            let item = root.emojiList[emojiGrid.currentIndex];
            if (item) insertEmoji(item.char, item.name);
        }
    }

    function insertEmoji(emojiChar, emojiName) {
        // Update recent list
        let newRecent = [{ char: emojiChar, name: emojiName, search: (emojiName + " " + emojiChar).toLowerCase() }];
        for (let it of root.recentEmojis) {
            if (it.char !== emojiChar) newRecent.push(it);
            if (newRecent.length >= 60) break;
        }
        root.recentEmojis = newRecent;

        // Save recent to cache file & copy/type
        saveAndTypeProc.command = [
            "sh", "-c",
            "printf '%s' " + JSON.stringify(JSON.stringify(newRecent)) + " > ~/.cache/emoji_recent.json; wl-copy " + JSON.stringify(emojiChar) + " && sleep 0.05 && wtype " + JSON.stringify(emojiChar) + " 2>/dev/null || true"
        ];
        saveAndTypeProc.running = true;
        root.close();
    }

    Process { id: saveAndTypeProc }

    // Backdrop layer
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Outer Frameless Card
    Rectangle {
        id: bgCard
        anchors.centerIn: parent
        width: 954
        height: 600
        radius: 16
        color: Qt.rgba(0.08, 0.09, 0.08, 0.95)
        border.color: Theme.outlineVariant || "#2f312c"
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: searchInput.forceActiveFocus()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // --- HEADER ROW ---
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Emoji"
                    font.pixelSize: 20
                    font.bold: true
                    color: Theme.onSurfaceColor || "#e4e2e0"
                }

                Item { Layout.fillWidth: true }
            }

            // --- SEARCH BAR ---
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 10
                color: "#1b1d19"
                border.color: searchInput.activeFocus ? (Theme.primary || "#b6ccba") : (Theme.outlineVariant || "#2a2d27")
                border.width: searchInput.activeFocus ? 2 : 1

                TextField {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    placeholderText: "Search emoji..."
                    placeholderTextColor: Theme.outline || "#686b65"
                    font.pixelSize: 13
                    color: Theme.onSurfaceColor || "#e4e2e0"
                    background: null
                    focus: true

                    onTextChanged: search(text)

                    Keys.onTabPressed: {
                        let nextIdx = (root.currentCategoryIndex + 1) % root.categories.length;
                        root.selectTab(nextIdx);
                    }
                    Keys.onBacktabPressed: {
                        let prevIdx = (root.currentCategoryIndex - 1 + root.categories.length) % root.categories.length;
                        root.selectTab(prevIdx);
                    }
                    Keys.onLeftPressed: {
                        if (emojiGrid.currentIndex > 0) {
                            emojiGrid.currentIndex--;
                            emojiGrid.positionViewAtIndex(emojiGrid.currentIndex, GridView.Contain);
                        }
                    }
                    Keys.onRightPressed: {
                        if (emojiGrid.currentIndex < emojiGrid.count - 1) {
                            emojiGrid.currentIndex++;
                            emojiGrid.positionViewAtIndex(emojiGrid.currentIndex, GridView.Contain);
                        }
                    }
                    Keys.onUpPressed: {
                        let cols = Math.floor(emojiGrid.width / emojiGrid.cellWidth);
                        if (emojiGrid.currentIndex - cols >= 0) {
                            emojiGrid.currentIndex -= cols;
                            emojiGrid.positionViewAtIndex(emojiGrid.currentIndex, GridView.Contain);
                        }
                    }
                    Keys.onDownPressed: {
                        let cols = Math.floor(emojiGrid.width / emojiGrid.cellWidth);
                        if (emojiGrid.currentIndex + cols < emojiGrid.count) {
                            emojiGrid.currentIndex += cols;
                            emojiGrid.positionViewAtIndex(emojiGrid.currentIndex, GridView.Contain);
                        }
                    }
                    Keys.onReturnPressed: {
                        root.insertCurrent();
                    }
                    Keys.onEscapePressed: {
                        root.close();
                    }
                }
            }

            // --- CATEGORY TABS ---
            ScrollView {
                id: tabScrollView
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                WheelHandler {
                    target: tabScrollView
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y !== 0) {
                            tabScrollView.ScrollBar.horizontal.position = Math.max(
                                0,
                                Math.min(
                                    1 - tabScrollView.ScrollBar.horizontal.size,
                                    tabScrollView.ScrollBar.horizontal.position - (event.angleDelta.y / 600)
                                )
                            );
                        }
                    }
                }

                Row {
                    id: tabRow
                    spacing: 6

                    Repeater {
                        id: tabRepeater
                        model: root.categories

                        delegate: Rectangle {
                            id: tabPill
                            height: 30
                            width: tabLabel.implicitWidth + 20
                            radius: 8
                            color: (root.currentCategoryIndex === index)
                                ? (Theme.primaryContainer || "#384b3e")
                                : (tabMouse.containsMouse ? "#242721" : "#1a1c18")
                            border.color: (root.currentCategoryIndex === index)
                                ? (Theme.primary || "#b6ccba")
                                : (Theme.outlineVariant || "#2c2f28")
                            border.width: 1

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData.name
                                font.pixelSize: 11
                                font.bold: (root.currentCategoryIndex === index)
                                color: (root.currentCategoryIndex === index)
                                    ? (Theme.onPrimaryContainerColor || "#ffffff")
                                    : (Theme.onSurfaceVariantColor || "#9fa39b")
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectTab(index)
                            }
                        }
                    }
                }
            }

            // --- EMOJI GRID ---
            GridView {
                id: emojiGrid
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 918
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 54
                cellHeight: 54
                model: root.emojiList
                reuseItems: true

                delegate: Rectangle {
                    id: emojiCell
                    width: 50
                    height: 50
                    radius: 8
                    color: (emojiGrid.currentIndex === index)
                        ? Qt.rgba(0.20, 0.23, 0.19, 0.95)
                        : (cellMouse.containsMouse ? "#222520" : "transparent")
                    border.color: (emojiGrid.currentIndex === index)
                        ? (Theme.primary || "#b6ccba")
                        : (cellMouse.containsMouse ? (Theme.outlineVariant || "#33362f") : "transparent")
                    border.width: (emojiGrid.currentIndex === index) ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.char
                        font.pixelSize: 26
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            emojiGrid.currentIndex = index;
                            root.insertCurrent();
                        }
                    }
                }
            }

            // --- FOOTER ROW ---
            RowLayout {
                Layout.fillWidth: true
                height: 24
                spacing: 8

                Text {
                    id: currentPreview
                    text: (emojiGrid.currentIndex >= 0 && emojiGrid.currentIndex < root.emojiList.length)
                        ? (root.emojiList[emojiGrid.currentIndex].char + "  " + root.emojiList[emojiGrid.currentIndex].name)
                        : ""
                    font.pixelSize: 12
                    color: Theme.onSurfaceVariantColor || "#c3c8c1"
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
