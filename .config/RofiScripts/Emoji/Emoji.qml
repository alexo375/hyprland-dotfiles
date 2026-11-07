import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    visible: true
    width: 954
    height: 600
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    property var categories: []
    property int currentCategoryIndex: 0
    property var emojiList: []

    Connections {
        target: backend
        function onCategoriesLoaded(cats) {
            root.categories = cats;
        }
        function onEmojisLoaded(emojis) {
            root.emojiList = emojis;
            if (emojiGrid.count > 0) emojiGrid.currentIndex = 0;
        }
    }

    function selectTab(index) {
        if (index < 0 || index >= root.categories.length) return;
        root.currentCategoryIndex = index;
        var cat = root.categories[index];
        if (cat) {
            searchInput.text = "";
            backend.selectCategory(cat.id);
        }
        var item = tabRepeater.itemAt(index);
        if (item && tabRow.width > tabScrollView.width) {
            var targetX = item.x - (tabScrollView.width - item.width) / 2;
            var maxScroll = tabRow.width - tabScrollView.width;
            var clampedX = Math.max(0, Math.min(targetX, maxScroll));
            tabScrollView.ScrollBar.horizontal.position = clampedX / tabRow.width;
        }
    }

    function insertCurrent() {
        if (emojiGrid.count > 0 && emojiGrid.currentIndex >= 0 && emojiGrid.currentIndex < root.emojiList.length) {
            var item = root.emojiList[emojiGrid.currentIndex];
            if (item) backend.insertEmoji(item.char, item.name);
        }
    }

    // Outer Frameless Card
    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(0.08, 0.09, 0.08, 0.95)
        border.color: themeColors.outlineVariant || "#2f312c"
        border.width: 1

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
                    color: themeColors.onSurface || "#e4e2e0"
                }

                Item { Layout.fillWidth: true }
            }

            // --- SEARCH BAR ---
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 10
                color: "#1b1d19"
                border.color: searchInput.activeFocus ? (themeColors.primary || "#b6ccba") : (themeColors.outlineVariant || "#2a2d27")
                border.width: searchInput.activeFocus ? 2 : 1

                TextField {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    placeholderText: "Search emoji..."
                    placeholderTextColor: themeColors.outline || "#686b65"
                    font.pixelSize: 13
                    color: themeColors.onSurface || "#e4e2e0"
                    background: null
                    focus: true

                    onTextChanged: {
                        var currentCat = root.categories[root.currentCategoryIndex];
                        backend.search(text, currentCat ? currentCat.id : "frequent");
                    }

                        Keys.onTabPressed: {
                            var nextIdx = (root.currentCategoryIndex + 1) % root.categories.length;
                            root.selectTab(nextIdx);
                        }
                        Keys.onBacktabPressed: {
                            var prevIdx = (root.currentCategoryIndex - 1 + root.categories.length) % root.categories.length;
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
                            var cols = Math.floor(emojiGrid.width / emojiGrid.cellWidth);
                            if (emojiGrid.currentIndex - cols >= 0) {
                                emojiGrid.currentIndex -= cols;
                                emojiGrid.positionViewAtIndex(emojiGrid.currentIndex, GridView.Contain);
                            }
                        }
                        Keys.onDownPressed: {
                            var cols = Math.floor(emojiGrid.width / emojiGrid.cellWidth);
                            if (emojiGrid.currentIndex + cols < emojiGrid.count) {
                                emojiGrid.currentIndex += cols;
                                emojiGrid.positionViewAtIndex(emojiGrid.currentIndex, GridView.Contain);
                            }
                        }
                        Keys.onReturnPressed: {
                            root.insertCurrent();
                        }
                        Keys.onEscapePressed: {
                            backend.close();
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
                                ? (themeColors.primaryContainer || "#384b3e")
                                : (tabMouse.containsMouse ? "#242721" : "#1a1c18")
                            border.color: (root.currentCategoryIndex === index)
                                ? (themeColors.primary || "#b6ccba")
                                : (themeColors.outlineVariant || "#2c2f28")
                            border.width: 1

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData.name
                                font.pixelSize: 11
                                font.bold: (root.currentCategoryIndex === index)
                                color: (root.currentCategoryIndex === index)
                                    ? (themeColors.onPrimaryContainer || "#ffffff")
                                    : (themeColors.onSurfaceVariant || "#9fa39b")
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

                delegate: Rectangle {
                    id: emojiCell
                    width: 50
                    height: 50
                    radius: 8
                    color: (emojiGrid.currentIndex === index)
                        ? Qt.rgba(0.20, 0.23, 0.19, 0.95)
                        : (cellMouse.containsMouse ? "#222520" : "transparent")
                    border.color: (emojiGrid.currentIndex === index)
                        ? (themeColors.primary || "#b6ccba")
                        : (cellMouse.containsMouse ? (themeColors.outlineVariant || "#33362f") : "transparent")
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
                    color: themeColors.onSurfaceVariant || "#c3c8c1"
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
