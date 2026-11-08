pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: theme

    property color primary: "#b6ccba"
    property color onPrimaryColor: "#223428"
    property color primaryContainer: "#384b3e"
    property color onPrimaryContainerColor: "#ffffff"
    property color surface: "#131412"
    property color onSurfaceColor: "#e4e2e0"
    property color surfaceVariant: "#434843"
    property color onSurfaceVariantColor: "#c3c8c1"
    property color outline: "#8d928c"
    property color outlineVariant: "#2d302a"
    property color surfaceContainer: "#1f201f"
    property color surfaceContainerHigh: "#292a29"
    property color surfaceContainerLowest: "#141513"

    FileView {
        path: "/home/alex/hyprland-dotfiles/.config/quickshell/overview/common/Appearance.colors.qml"
        onLoaded: {
            let lines = text().split("\n");
            for (let l of lines) {
                l = l.trim();
                let m = l.match(/property color m3(\w+):\s*"([^"]+)"/);
                if (m) {
                    let k = m[1];
                    if (k === "primary") theme.primary = m[2];
                    else if (k === "onPrimary") theme.onPrimaryColor = m[2];
                    else if (k === "primaryContainer") theme.primaryContainer = m[2];
                    else if (k === "onPrimaryContainer") theme.onPrimaryContainerColor = m[2];
                    else if (k === "surface") theme.surface = m[2];
                    else if (k === "onSurface") theme.onSurfaceColor = m[2];
                    else if (k === "surfaceVariant") theme.surfaceVariant = m[2];
                    else if (k === "onSurfaceVariant") theme.onSurfaceVariantColor = m[2];
                    else if (k === "outline") theme.outline = m[2];
                    else if (k === "outlineVariant") theme.outlineVariant = m[2];
                    else if (k === "surfaceContainer") theme.surfaceContainer = m[2];
                    else if (k === "surfaceContainerHigh") theme.surfaceContainerHigh = m[2];
                    else if (k === "surfaceContainerLowest") theme.surfaceContainerLowest = m[2];
                }
            }
        }
    }
}
