#!/usr/bin/env bash

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/hyprland-dotfiles}"
TARGET="${1:-$DOTFILES_DIR}"

# If target is inside dotfiles, ensure nvim starts in dotfiles directory with target opened
if [[ "$TARGET" == "$DOTFILES_DIR"* ]]; then
    exec kitty --directory "$DOTFILES_DIR" -e nvim "$TARGET"
else
    exec kitty -e nvim "$TARGET"
fi
