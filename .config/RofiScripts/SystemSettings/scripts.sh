#! /bin/sh

: "${LC_ALL:=C.UTF-8}"
: "${LANG:=C.UTF-8}"
export LC_ALL LANG

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/hyprland-dotfiles}"
exec "$DOTFILES_DIR/.config/hypr/scripts/edit_config.sh" "$DOTFILES_DIR/.config/hypr/scripts"
