#!/usr/bin/env bash

# QuickShell Clipboard Manager launcher
if ! qs ipc -p "$HOME/.config/quickshell/tools" call clipboard toggle 2>/dev/null; then
    systemd-run --user --unit=quickshell-tools qs -p "$HOME/.config/quickshell/tools" -n >/dev/null 2>&1 || nohup qs -p "$HOME/.config/quickshell/tools" -n >/dev/null 2>&1 &
    for i in {1..30}; do
        if qs ipc -p "$HOME/.config/quickshell/tools" call clipboard toggle 2>/dev/null; then
            break
        fi
        sleep 0.05
    done
fi
