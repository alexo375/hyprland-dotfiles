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
    WlrLayershell.namespace: "quickshell:clipboard"
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Active column: 0 = Images, 1 = Text (defaults to Text)
    property int activeColumn: 1
    property var allImages: []
    property var allTexts: []
    property var imageList: []
    property var textList: []
    property var metaCache: ({})
    property int savedIndex: -1
    property var pendingImages: []
    property var pendingTexts: []
    property var pendingOlderCids: []
    property var pendingDeletions: []

    function open() {
        root.visible = true;
        searchInput.text = "";
        root.activeColumn = 1;
        loadHistory();
        searchInput.forceActiveFocus();
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        if (root.visible) close();
        else open();
    }

    // Hyprland Focus grab to ensure keyboard events go to searchInput
    HyprlandFocusGrab {
        id: grab
        windows: [root]
        active: root.visible
        onCleared: () => {
            root.close();
        }
    }

    // Read cached metadata
    FileView {
        id: metaCacheFile
        path: "/home/alex/.cache/cliphist_meta.json"
        onLoaded: {
            try {
                root.metaCache = JSON.parse(text()) || {};
            } catch (e) {
                root.metaCache = {};
            }
        }
    }

    // Background process to run cliphist list
    Process {
        id: cliphistProc
        command: ["cliphist", "list"]
        property var rawLines: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line && line.trim()) {
                    cliphistProc.rawLines.push(line);
                }
            }
        }
        onExited: (code, status) => {
            parseHistory(cliphistProc.rawLines);
        }
    }

    function loadHistory() {
        cliphistProc.rawLines = [];
        cliphistProc.running = false;
        cliphistProc.running = true;
    }

    function parseHistory(lines) {
        let now = new Date();
        let imagesRaw = [];
        let textsRaw = [];
        let imgRank = 0;
        let txtRank = 0;

        for (let line of lines) {
            let tabIdx = line.indexOf("\t");
            if (tabIdx === -1) continue;
            let cid = line.substring(0, tabIdx);
            let content = line.substring(tabIdx + 1);

            let binMatch = content.match(/^\[\[ binary data (\S+ \S+) (\w+) (\d+x\d+) \]\]$/);
            if (binMatch) {
                imgRank++;
                imagesRaw.push({
                    rank: imgRank,
                    cid: cid,
                    size: binMatch[1],
                    ext: binMatch[2],
                    dims: binMatch[3],
                    line: line
                });
            } else {
                txtRank++;
                let clean = content.replace(/\s+/g, " ").trim();
                textsRaw.push({
                    rank: txtRank,
                    cid: cid,
                    clean: clean,
                    line: line
                });
            }
        }

        // Format dates helper
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        function formatSecDate(dt) {
            let diff = Math.floor((now - dt) / (1000 * 60 * 60 * 24));
            let mon = months[dt.getMonth()];
            let day = dt.getDate();
            if (diff === 0 && now.getDate() === day) return "Today · " + day + " " + mon;
            if (diff === 1 || (diff === 0 && now.getDate() !== day)) return "Yesterday · " + day + " " + mon;
            return day + " " + mon;
        }

        function pad(n) { return n < 10 ? "0" + n : "" + n; }

        // Process texts
        let texts = [];
        for (let t of textsRaw) {
            let cidStr = t.cid;
            let cachedDt = root.metaCache[cidStr];
            let itemDate = now;
            if (cachedDt) {
                let parts = cachedDt.split(" ");
                if (parts.length >= 5) {
                    itemDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]), parseInt(parts[3]), parseInt(parts[4]));
                }
            }
            let timeStr = pad(itemDate.getHours()) + ":" + pad(itemDate.getMinutes());
            let secDate = formatSecDate(itemDate);
            let dispDt = itemDate.getFullYear() + "-" + pad(itemDate.getMonth() + 1) + "-" + pad(itemDate.getDate()) + " " + timeStr;

            texts.push({
                cid: t.cid,
                rank: t.rank,
                text: t.clean,
                title: "#" + t.rank + "  " + t.clean,
                time_str: timeStr,
                section_date: secDate,
                display_dt: dispDt,
                search: ("#" + t.rank + " " + t.rank + " " + t.clean + " " + dispDt + " " + timeStr).toLowerCase(),
                raw_line: t.line
            });
        }

        // Process images
        let images = [];
        let topCidsToDecode = [];
        let olderCidsToDecode = [];

        for (let i = 0; i < imagesRaw.length; i++) {
            let img = imagesRaw[i];
            let thumbPath = "/tmp/cliphist-thumbs-1000/" + img.cid + ".png";
            let cachedDt = root.metaCache[img.cid] || "";
            let dispDt = "";
            if (cachedDt) {
                let p = cachedDt.split(" ");
                if (p.length >= 5) {
                    dispDt = p[0] + "-" + pad(parseInt(p[1])) + "-" + pad(parseInt(p[2])) + " " + pad(parseInt(p[3])) + ":" + pad(parseInt(p[4]));
                }
            }
            images.push({
                cid: img.cid,
                rank: img.rank,
                dims: img.dims,
                size: img.size,
                display_dt: dispDt,
                title: "#" + img.rank + " Image " + img.dims,
                search: ("#" + img.rank + " " + img.rank + " image " + img.dims + " " + dispDt).toLowerCase(),
                thumb_url: "file://" + thumbPath,
                raw_line: img.line
            });

            if (i < 5) {
                topCidsToDecode.push(img.cid);
            } else if (i < 30) {
                olderCidsToDecode.push(img.cid);
            }
        }

        root.pendingImages = images;
        root.pendingTexts = texts;
        root.pendingOlderCids = olderCidsToDecode;

        if (topCidsToDecode.length > 0) {
            topThumbDecoder.command = [
                "sh", "-c",
                "mkdir -p /tmp/cliphist-thumbs-1000 && for c in " + topCidsToDecode.join(" ") + "; do [ -f /tmp/cliphist-thumbs-1000/$c.png ] || cliphist decode $c > /tmp/cliphist-thumbs-1000/$c.png 2>/dev/null; done"
            ];
            topThumbDecoder.running = true;
        } else {
            applyHistoryData();
        }
    }

    Process {
        id: topThumbDecoder
        onExited: (code, status) => {
            applyHistoryData();
        }
    }

    function applyHistoryData() {
        root.allImages = root.pendingImages;
        root.allTexts = root.pendingTexts;
        filterResults(searchInput.text);

        if (root.pendingOlderCids && root.pendingOlderCids.length > 0) {
            olderThumbDecoder.command = [
                "sh", "-c",
                "for c in " + root.pendingOlderCids.join(" ") + "; do [ -f /tmp/cliphist-thumbs-1000/$c.png ] || cliphist decode $c > /tmp/cliphist-thumbs-1000/$c.png 2>/dev/null; done"
            ];
            olderThumbDecoder.running = true;
        }
    }

    Process {
        id: olderThumbDecoder
    }

    function filterResults(query, restoreIndex) {
        let q = (query || "").trim().toLowerCase();
        if (!q) {
            root.imageList = root.allImages;
            root.textList = root.allTexts;
        } else {
            root.imageList = root.allImages.filter(img => img.search.includes(q) || img.title.toLowerCase().includes(q));
            root.textList = root.allTexts.filter(t => t.search.includes(q) || t.text.toLowerCase().includes(q));
        }

        if (restoreIndex !== undefined && restoreIndex >= 0) {
            if (root.activeColumn === 1) {
                if (root.textList.length === 0) {
                    textListView.currentIndex = -1;
                } else {
                    let newIdx = Math.max(0, Math.min(restoreIndex, root.textList.length - 1));
                    textListView.currentIndex = -1;
                    textListView.currentIndex = newIdx;
                    textListView.positionViewAtIndex(newIdx, ListView.Contain);
                }
            } else {
                if (root.imageList.length === 0) {
                    imageListView.currentIndex = -1;
                } else {
                    let newIdx = Math.max(0, Math.min(restoreIndex, root.imageList.length - 1));
                    imageListView.currentIndex = -1;
                    imageListView.currentIndex = newIdx;
                    imageListView.positionViewAtIndex(newIdx, ListView.Contain);
                }
            }
        } else {
            if (root.activeColumn === 1) {
                textListView.currentIndex = root.textList.length > 0 ? 0 : -1;
            } else {
                imageListView.currentIndex = root.imageList.length > 0 ? 0 : -1;
            }
        }
    }

    function copyCurrent() {
        if (root.activeColumn === 0 && imageListView.count > 0 && imageListView.currentIndex >= 0) {
            let item = root.imageList[imageListView.currentIndex];
            if (item) {
                copyProc.command = ["sh", "-c", "cliphist decode " + item.cid + " | wl-copy --type image/png"];
                copyProc.running = true;
                root.close();
            }
        } else if (root.activeColumn === 1 && textListView.count > 0 && textListView.currentIndex >= 0) {
            let item = root.textList[textListView.currentIndex];
            if (item) {
                copyProc.command = ["sh", "-c", "cliphist decode " + item.cid + " | wl-copy"];
                copyProc.running = true;
                root.close();
            }
        }
    }

    function processNextDelete() {
        if (root.pendingDeletions.length === 0) return;
        let cid = root.pendingDeletions.shift();
        deleteProc.command = [
            "sh", "-c",
            "cliphist list | grep -m1 -P '^" + cid + "\t' | cliphist delete; rm -f /tmp/cliphist-thumbs-1000/" + cid + ".png"
        ];
        deleteProc.running = true;
    }

    function deleteCurrent() {
        let isImage = (root.activeColumn === 0);
        let curIdx = isImage ? imageListView.currentIndex : textListView.currentIndex;
        let target = null;

        if (isImage && imageListView.count > 0 && curIdx >= 0) {
            target = root.imageList[curIdx];
            root.allImages = root.allImages.filter(it => it.cid !== target.cid);
            root.savedIndex = curIdx;
        } else if (!isImage && textListView.count > 0 && curIdx >= 0) {
            target = root.textList[curIdx];
            root.allTexts = root.allTexts.filter(it => it.cid !== target.cid);
            root.savedIndex = curIdx;
        }

        if (target && target.cid) {
            if (root.metaCache && root.metaCache[target.cid]) {
                delete root.metaCache[target.cid];
            }
            root.pendingDeletions.push(target.cid);
            if (!deleteProc.running) {
                processNextDelete();
            }
        }

        let preserve = root.savedIndex;
        root.savedIndex = -1;
        filterResults(searchInput.text, preserve);
    }

    Process { id: copyProc }
    Process {
        id: deleteProc
        onExited: (code, status) => {
            processNextDelete();
        }
    }

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
        width: 1380
        height: 820
        radius: 18
        color: Qt.rgba(0.08, 0.09, 0.08, 0.95)
        border.color: Theme.outlineVariant || "#2f312c"
        border.width: 1

        // Prevent click propagation to backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: searchInput.forceActiveFocus()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            // --- HEADER ROW ---
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Clipboard"
                    font.pixelSize: 20
                    font.bold: true
                    color: Theme.onSurfaceColor || "#e4e2e0"
                }

                Item { Layout.fillWidth: true }
            }

            // --- SEARCH BAR ---
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 10
                color: "#1b1d19"
                border.color: searchInput.activeFocus ? (Theme.primary || "#b6ccba") : (Theme.outlineVariant || "#2a2d27")
                border.width: searchInput.activeFocus ? 2 : 1

                TextField {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    placeholderText: "Search clipboard..."
                    placeholderTextColor: Theme.outline || "#686b65"
                    font.pixelSize: 14
                    color: Theme.onSurfaceColor || "#e4e2e0"
                    background: null
                    focus: true

                    onTextChanged: filterResults(text)

                    Keys.onUpPressed: {
                        if (root.activeColumn === 0) {
                            if (imageListView.currentIndex > 0) imageListView.currentIndex--;
                            imageListView.positionViewAtIndex(imageListView.currentIndex, ListView.Contain);
                        } else {
                            if (textListView.currentIndex > 0) textListView.currentIndex--;
                            textListView.positionViewAtIndex(textListView.currentIndex, ListView.Contain);
                        }
                    }
                    Keys.onDownPressed: {
                        if (root.activeColumn === 0) {
                            if (imageListView.currentIndex < imageListView.count - 1) imageListView.currentIndex++;
                            imageListView.positionViewAtIndex(imageListView.currentIndex, ListView.Contain);
                        } else {
                            if (textListView.currentIndex < textListView.count - 1) textListView.currentIndex++;
                            textListView.positionViewAtIndex(textListView.currentIndex, ListView.Contain);
                        }
                    }
                    Keys.onLeftPressed: {
                        root.activeColumn = 0;
                    }
                    Keys.onRightPressed: {
                        root.activeColumn = 1;
                    }
                    Keys.onReturnPressed: {
                        root.copyCurrent();
                    }
                    Keys.onDeletePressed: {
                        root.deleteCurrent();
                    }
                    Keys.onEscapePressed: {
                        root.close();
                    }
                }
            }

            // --- MAIN CONTENT: TWO COLUMNS ---
            Row {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                // ==================== LEFT COLUMN: IMAGES ====================
                ColumnLayout {
                    width: 560
                    height: parent.height
                    spacing: 10

                    Text {
                        text: "IMAGES · " + root.imageList.length
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 0.5
                        color: (root.activeColumn === 0) ? (Theme.primary || "#b6ccba") : (Theme.onSurfaceVariantColor || "#8f928b")
                    }

                    ListView {
                        id: imageListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 12
                        model: root.imageList
                        reuseItems: true

                        delegate: Rectangle {
                            id: imgDelegate
                            width: imageListView.width
                            height: 356
                            radius: 10
                            color: (root.activeColumn === 0 && imageListView.currentIndex === index)
                                ? Qt.rgba(0.18, 0.20, 0.17, 0.95)
                                : Qt.rgba(0.12, 0.13, 0.11, 0.85)
                            border.color: (root.activeColumn === 0 && imageListView.currentIndex === index)
                                ? (Theme.primary || "#b6ccba")
                                : (Theme.outlineVariant || "#252722")
                            border.width: (root.activeColumn === 0 && imageListView.currentIndex === index) ? 2 : 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 304
                                    clip: true

                                    Image {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: parent.height
                                        source: modelData.thumb_url
                                        sourceSize.width: 540
                                        sourceSize.height: 304
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    height: 24

                                    Text {
                                        text: modelData.title
                                        font.pixelSize: 12
                                        font.family: "FiraCode Nerd Font, monospace"
                                        color: (root.activeColumn === 0 && imageListView.currentIndex === index)
                                            ? (Theme.primary || "#b6ccba")
                                            : (Theme.onSurfaceVariantColor || "#c3c8c1")
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        visible: !!modelData.display_dt
                                        text: modelData.display_dt || ""
                                        font.pixelSize: 11
                                        font.family: "FiraCode Nerd Font, monospace"
                                        color: (root.activeColumn === 0 && imageListView.currentIndex === index)
                                            ? (Theme.primary || "#b6ccba")
                                            : (Theme.outline || "#8d928c")
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activeColumn = 0;
                                    imageListView.currentIndex = index;
                                    root.copyCurrent();
                                }
                            }
                        }
                    }
                }

                // Divider line
                Rectangle {
                    width: 1
                    height: parent.height
                    color: Theme.outlineVariant || "#262923"
                }

                // ==================== RIGHT COLUMN: TEXT ====================
                ColumnLayout {
                    width: parent.width - 560 - 1 - 16
                    height: parent.height
                    spacing: 10

                    Text {
                        text: "TEXT · " + root.textList.length
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 0.5
                        color: (root.activeColumn === 1) ? (Theme.primary || "#b6ccba") : (Theme.onSurfaceVariantColor || "#8f928b")
                    }

                    ListView {
                        id: textListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: root.textList
                        reuseItems: true

                        section.property: "section_date"
                        section.criteria: ViewSection.FullString
                        section.delegate: Rectangle {
                            width: textListView.width
                            height: 28
                            color: "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 10

                                Text {
                                    text: section
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                    color: Theme.primary || "#b6ccba"
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Theme.outlineVariant || "#2a2d27"
                                }
                            }
                        }

                        delegate: Rectangle {
                            id: txtDelegate
                            width: textListView.width
                            height: 48
                            radius: 8
                            color: (root.activeColumn === 1 && textListView.currentIndex === index)
                                ? Qt.rgba(0.18, 0.20, 0.17, 0.95)
                                : Qt.rgba(0.12, 0.13, 0.11, 0.85)
                            border.color: (root.activeColumn === 1 && textListView.currentIndex === index)
                                ? (Theme.primary || "#b6ccba")
                                : (Theme.outlineVariant || "#252722")
                            border.width: (root.activeColumn === 1 && textListView.currentIndex === index) ? 2 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    text: "#" + modelData.rank
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: (root.activeColumn === 1 && textListView.currentIndex === index)
                                        ? (Theme.primary || "#b6ccba")
                                        : (Theme.outline || "#8d928c")
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    color: (root.activeColumn === 1 && textListView.currentIndex === index)
                                        ? (Theme.onSurfaceColor || "#e4e2e0")
                                        : (Theme.onSurfaceVariantColor || "#c3c8c1")
                                }

                                Text {
                                    text: modelData.time_str
                                    font.pixelSize: 11
                                    color: (root.activeColumn === 1 && textListView.currentIndex === index)
                                        ? (Theme.primary || "#b6ccba")
                                        : (Theme.outline || "#8d928c")
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activeColumn = 1;
                                    textListView.currentIndex = index;
                                    root.copyCurrent();
                                }
                            }
                        }
                    }
                }
            }

            // --- FOOTER ROW ---
            RowLayout {
                Layout.fillWidth: true
                height: 24
                spacing: 12

                Text {
                    text: (root.activeColumn === 0 ? "← IMAGES" : "TEXT →") + "  ·  Enter: Copy  ·  Del: Delete  ·  Esc: Close"
                    font.pixelSize: 11
                    color: Theme.outline || "#8d928c"
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
