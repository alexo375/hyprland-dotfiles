#! /bin/sh

: "${LC_ALL:=C.UTF-8}"
: "${LANG:=C.UTF-8}"
export LC_ALL LANG

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/hyprland-dotfiles}"

back_label="← Back"

chosen=$(
	printf "%s\n" \
		"$back_label" \
		" Performance" \
		" Hyprland Config" \
		" NixOS Config" \
		"󰆍 Scripts" |
		rofi -dmenu -i -selected-row 1 -config "$HOME/.config/RofiScripts/SystemSettings/S.rasi" \
			-kb-move-char-back "" -kb-move-char-forward "" -kb-custom-1 "Left" \
			-kb-accept-entry "Control+j,Control+m,Return,KP_Enter,Right"
)
rc=$?

if [ "$rc" -eq 10 ] || [ "$chosen" = "$back_label" ]; then
	~/.config/RofiScripts/Launcher/Launcher.sh
	exit 0
fi

case "$chosen" in
	" Performance") ~/.config/RofiScripts/Performance/performance.sh ;;
	" Hyprland Config") ~/.config/RofiScripts/SystemSettings/hyprland.sh ;;
	" NixOS Config") ~/.config/RofiScripts/SystemSettings/nixos.sh ;;
	"󰆍 Scripts") code "$DOTFILES_DIR/.config/hypr/scripts" ;;
	*) exit 1 ;;
esac
