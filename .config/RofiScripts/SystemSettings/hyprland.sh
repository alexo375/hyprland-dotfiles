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
		" Master Config" \
		"󱓞 Autostart" \
		"󰍹 Monitors" \
		"󰍽 Input & Keyboard" \
		"󰌌 Keybindings" \
		" Look and Feel" \
		" Window Rules" \
		"󱂬 Workspaces" \
		"󰪫 Environment" \
		" Default Programs" \
		" Permissions" \
		"󰥔 Idle Timers" \
		"󰌾 Lockscreen" |
		rofi -dmenu -i -selected-row 1 -config "$HOME/.config/RofiScripts/SystemSettings/S_hyprland.rasi" -kb-move-char-back "" -kb-move-char-forward "" -kb-custom-1 "Left" -kb-accept-entry "Control+j,Control+m,Return,KP_Enter,Right"
)
rc=$?

if [ "$rc" -eq 10 ] || [ "$chosen" = "$back_label" ]; then
	~/.config/RofiScripts/Launcher/System.sh
	exit 0
fi

case "$chosen" in
   " Master Config") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/hyprland.lua" ;;
   "󱓞 Autostart") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/autostart.lua" ;;
   "󰍹 Monitors") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/monitors.lua" ;;
   "󰍽 Input & Keyboard") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/input.lua" ;;
   "󰌌 Keybindings") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/keybinds.lua" ;;
   " Look and Feel") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/lookandfeel.lua" ;;
   " Window Rules") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/windowsandworkspaces.lua" ;;
   "󱂬 Workspaces") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/workspaces.lua" ;;
   "󰪫 Environment") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/environment.lua" ;;
   " Default Programs") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/programs.lua" ;;
   " Permissions") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/lua/permissions.lua" ;;
   "󰥔 Idle Timers") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/hypridle.conf" ;;
   "󰌾 Lockscreen") "$EDIT_CMD" "$DOTFILES_DIR/.config/hypr/hyprlock.conf" ;;
   *) exit 1 ;;
esac
