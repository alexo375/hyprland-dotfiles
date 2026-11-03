#!/usr/bin/env bash

# Clipboard menu wrapper for Hyprland & Rofi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ensure no orphaned rofi instance holds the pidfile lock
pkill -x rofi 2>/dev/null || true
pkill -x .rofi-wrapped 2>/dev/null || true

exec python3 "$SCRIPT_DIR/Clipboard.py" "$@"
