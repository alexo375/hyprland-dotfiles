#! /bin/sh

: "${LC_ALL:=C.UTF-8}"
: "${LANG:=C.UTF-8}"
export LC_ALL LANG

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/hyprland-dotfiles}"
EDIT_CMD="$HOME/.config/hypr/scripts/edit_config.sh"

back_label="← Back"

chosen=$(
	printf "%s\n" \
		"$back_label" \
		"󰉋 NixOS Project" \
		" Flake" \
		" Configuration" \
		"󰢮 Hardware" \
		"󰋜 Home Manager" \
		"󰏓 Flatpak Apps" \
		"󰂄 Power" \
		"󰏖 Custom Packages" |
		rofi -dmenu -i -selected-row 1 -config "$HOME/.config/RofiScripts/SystemSettings/S.rasi" -kb-move-char-back "" -kb-move-char-forward "" -kb-custom-1 "Left" -kb-accept-entry "Control+j,Control+m,Return,KP_Enter,Right"
)
rc=$?

if [ "$rc" -eq 10 ] || [ "$chosen" = "$back_label" ]; then
	~/.config/RofiScripts/Launcher/System.sh
	exit 0
fi

case "$chosen" in
   "󰉋 NixOS Project") "$EDIT_CMD" "$DOTFILES_DIR/NixOS" ;;
   " Flake") "$EDIT_CMD" "$DOTFILES_DIR/NixOS/flake.nix" ;;
   " Configuration") "$EDIT_CMD" "$DOTFILES_DIR/NixOS/configuration.nix" ;;
   "󰢮 Hardware") "$EDIT_CMD" "$DOTFILES_DIR/NixOS/hardware-configuration.nix" ;;
   "󰋜 Home Manager") "$EDIT_CMD" "$DOTFILES_DIR/NixOS/home.nix" ;;
   "󰏓 Flatpak Apps") "$EDIT_CMD" "$DOTFILES_DIR/NixOS/modules/flatpak.nix" ;;
   "󰂄 Power") "$EDIT_CMD" "$DOTFILES_DIR/NixOS/modules/power.nix" ;;
   "󰏖 Custom Packages") "$EDIT_CMD" "$DOTFILES_DIR/NixOS/pkgs" ;;
   *) exit 1 ;;
esac
