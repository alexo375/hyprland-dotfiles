import Quickshell
import Quickshell.Io
import QtQuick
import "."

Scope {
    id: rootScope

    ClipboardPopup {
        id: clipboardPopup
    }

    EmojiPopup {
        id: emojiPopup
    }

    IpcHandler {
        target: "clipboard"

        function toggle() {
            if (clipboardPopup.visible) {
                clipboardPopup.close();
            } else {
                emojiPopup.close();
                clipboardPopup.open();
            }
        }
        function open() {
            emojiPopup.close();
            clipboardPopup.open();
        }
        function close() {
            clipboardPopup.close();
        }
    }

    IpcHandler {
        target: "emoji"

        function toggle() {
            if (emojiPopup.visible) {
                emojiPopup.close();
            } else {
                clipboardPopup.close();
                emojiPopup.open();
            }
        }
        function open() {
            clipboardPopup.close();
            emojiPopup.open();
        }
        function close() {
            emojiPopup.close();
        }
    }
}
