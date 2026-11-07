#!/usr/bin/env bash

# QML Clipboard Manager launcher for Hyprland
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure QML imports are found
export QML2_IMPORT_PATH="/nix/store/3vd002px7rdr8cmr1wxh3628fpkrbhg2-qtdeclarative-6.11.1/lib/qt-6/qml:${QML2_IMPORT_PATH}"

# Pick Python interpreter with PyQt6 available
if python3 -c "import PyQt6.QtQuick" 2>/dev/null; then
    PY_BIN="python3"
elif [ -x "/nix/store/867ngqlqx6278w934l1km5kycxd1srpf-python3-3.14.6-env/bin/python3" ]; then
    PY_BIN="/nix/store/867ngqlqx6278w934l1km5kycxd1srpf-python3-3.14.6-env/bin/python3"
else
    PY_BIN="python3"
fi

exec "$PY_BIN" "$SCRIPT_DIR/Clipboard.py" "$@"
