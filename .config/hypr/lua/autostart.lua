-------------------
---- AUTOSTART ----
-------------------

local home = os.getenv("HOME") or "/home/alex"

hl.on("hyprland.start", function()
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
	hl.dispatch(hl.dsp.focus({ workspace = 1 }))
	-- Launch apps into special:magic workspace silently
	-- hl.dispatch(hl.dsp.exec_cmd("AmneziaVPN", { workspace = "special:magic", no_initial_focus = true }))
	hl.dispatch(hl.dsp.exec_cmd("Throne", { workspace = "special:magic", no_initial_focus = true }))
	-- Background daemons & utils (centralized script)
	hl.exec_cmd(home .. "/.config/hypr/scripts/session_daemons.sh start")
end)
