import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    visible: true
    width: 1380
    height: 820
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    // Active column: 0 = Images, 1 = Text (defaults to Text)
    property int activeColumn: 1
    property var imageList: []
    property var textList: []
    property int totalImages: 0
    property int totalTexts: 0
    property int savedIndex: -1

    Connections {
        target: backend
        function onDataLoaded(images, texts, countImg, countTxt) {
            root.imageList = images;
            root.textList = texts;
            root.totalImages = countImg;
            root.totalTexts = countTxt;
            if (textListView.count > 0) textListView.currentIndex = 0;
            if (imageListView.count > 0) imageListView.currentIndex = 0;
        }
        function onFilterCompleted(images, texts) {
            var restoreIdx = root.savedIndex;
            root.savedIndex = -1;

            root.imageList = images;
            root.textList = texts;

            if (restoreIdx >= 0) {
                if (root.activeColumn === 1) {
                    if (texts.length === 0) {
                        textListView.currentIndex = -1;
                    } else {
                        var newIdx = Math.max(0, Math.min(restoreIdx, texts.length - 1));
                        textListView.currentIndex = newIdx;
                        textListView.positionViewAtIndex(newIdx, ListView.Contain);
                    }
                } else {
                    if (images.length === 0) {
                        imageListView.currentIndex = -1;
                    } else {
                        var newIdx = Math.max(0, Math.min(restoreIdx, images.length - 1));
                        imageListView.currentIndex = newIdx;
                        imageListView.positionViewAtIndex(newIdx, ListView.Contain);
                    }
                }
            } else {
                if (root.activeColumn === 1) {
                    if (textListView.currentIndex >= texts.length) {
                        textListView.currentIndex = Math.max(0, texts.length - 1);
                    }
                } else {
                    if (imageListView.currentIndex >= images.length) {
                        imageListView.currentIndex = Math.max(0, images.length - 1);
                    }
                }
            }
        }
    }

    function copyCurrent() {
        if (root.activeColumn === 0 && imageListView.count > 0 && imageListView.currentIndex >= 0) {
            var itemImg = root.imageList[imageListView.currentIndex];
            if (itemImg) backend.copyItem(itemImg.cid, true);
        } else if (root.activeColumn === 1 && textListView.count > 0 && textListView.currentIndex >= 0) {
            var itemTxt = root.textList[textListView.currentIndex];
            if (itemTxt) backend.copyItem(itemTxt.cid, false);
        }
    }

    function deleteCurrent() {
        if (root.activeColumn === 0 && imageListView.count > 0 && imageListView.currentIndex >= 0) {
            root.savedIndex = imageListView.currentIndex;
            var itemImg = root.imageList[imageListView.currentIndex];
            if (itemImg) backend.deleteItem(itemImg.cid, true);
        } else if (root.activeColumn === 1 && textListView.count > 0 && textListView.currentIndex >= 0) {
            root.savedIndex = textListView.currentIndex;
            var itemTxt = root.textList[textListView.currentIndex];
            if (itemTxt) backend.deleteItem(itemTxt.cid, false);
        }
    }

    // Outer Frameless Card
    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(0.08, 0.09, 0.08, 0.95)
        border.color: themeColors.outlineVariant || "#2f312c"
        border.width: 1

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
                    color: themeColors.onSurface || "#e4e2e0"
                }

                Item { Layout.fillWidth: true }
            }

            // --- SEARCH BAR ---
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 10
                color: "#1b1d19"
                border.color: searchInput.activeFocus ? (themeColors.primary || "#b6ccba") : (themeColors.outlineVariant || "#2a2d27")
                border.width: searchInput.activeFocus ? 2 : 1

                TextField {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    placeholderText: "Search clipboard..."
                    placeholderTextColor: themeColors.outline || "#686b65"
                    font.pixelSize: 14
                    color: themeColors.onSurface || "#e4e2e0"
                    background: null
                    focus: true

                    onTextChanged: backend.search(text)

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
                            backend.close();
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
                        color: (root.activeColumn === 0) ? (themeColors.primary || "#b6ccba") : (themeColors.onSurfaceVariant || "#8f928b")
                    }

                    ListView {
                        id: imageListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 12
                        model: root.imageList

                        delegate: Rectangle {
                            id: imgDelegate
                            width: imageListView.width
                            height: 356
                            radius: 10
                            color: (root.activeColumn === 0 && imageListView.currentIndex === index)
                                ? Qt.rgba(0.18, 0.20, 0.17, 0.95)
                                : Qt.rgba(0.12, 0.13, 0.11, 0.85)
                            border.color: (root.activeColumn === 0 && imageListView.currentIndex === index)
                                ? (themeColors.primary || "#b6ccba")
                                : (themeColors.outlineVariant || "#252722")
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
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        cache: true
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
                                            ? (themeColors.primary || "#b6ccba")
                                            : (themeColors.onSurfaceVariant || "#c3c8c1")
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        visible: !!modelData.display_dt
                                        text: modelData.display_dt || ""
                                        font.pixelSize: 11
                                        font.family: "FiraCode Nerd Font, monospace"
                                        color: (root.activeColumn === 0 && imageListView.currentIndex === index)
                                            ? (themeColors.primary || "#b6ccba")
                                            : (themeColors.outline || "#8d928c")
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
                    color: themeColors.outlineVariant || "#262923"
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
                        color: (root.activeColumn === 1) ? (themeColors.primary || "#b6ccba") : (themeColors.onSurfaceVariant || "#8f928b")
                    }

                    ListView {
                        id: textListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: root.textList

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
                                    color: themeColors.primary || "#b6ccba"
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: themeColors.outlineVariant || "#2a2d27"
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
                                ? (themeColors.primary || "#b6ccba")
                                : (themeColors.outlineVariant || "#252722")
                            border.width: (root.activeColumn === 1 && textListView.currentIndex === index) ? 2 : 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 12

                                Text {
                                    text: "#" + modelData.rank
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.family: "FiraCode Nerd Font, monospace"
                                    color: (root.activeColumn === 1 && textListView.currentIndex === index)
                                        ? (themeColors.primary || "#b6ccba")
                                        : (themeColors.outline || "#7c8078")
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.text
                                    font.pixelSize: 13
                                    color: themeColors.onSurface || "#e4e2e0"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: !!modelData.time_str
                                    text: modelData.time_str || ""
                                    font.pixelSize: 11
                                    font.family: "FiraCode Nerd Font, monospace"
                                    color: (root.activeColumn === 1 && textListView.currentIndex === index)
                                        ? (themeColors.primary || "#b6ccba")
                                        : (themeColors.outline || "#7c8078")
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
        }
    }
}
