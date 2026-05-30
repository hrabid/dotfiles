-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

-- Autostart necessary processes (like notifications daemons, status bars, etc.)
-- Or execute your favorite apps at launch like this:
--
hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("swaync")
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("flameshot")
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")
	hl.exec_cmd("wl-paste --primary --watch cliphist store")
	hl.exec_cmd("wl-clip-persist --clipboard regular")
	hl.exec_cmd("wl-clip-persist --clipboard primary")
	hl.exec_cmd("snappy-switcher --daemon")
	hl.exec_cmd("ibus-daemon -drx")
	hl.dispatch(hl.dsp.exec_cmd("alacritty", { workspace = "1" }))
	hl.dispatch(hl.dsp.exec_cmd("brave", { workspace = "2" }))
	--  hl.dispatch(hl.dsp.exec_cmd("obsidian --no-sandbox", { workspace = "3" }))
	--  hl.dispatch(hl.dsp.exec_cmd("discord",    { workspace = "4", silent = true }))
	--  hl.dispatch(hl.dsp.exec_cmd("spotify",    { workspace = "5", silent = true }))
end)
