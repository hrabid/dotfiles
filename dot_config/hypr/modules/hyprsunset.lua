-- ~/.config/hypr/modules/hyprsunset.lua
hl.on("hyprland.start", function()
	hl.exec_cmd("hyprsunset")
end)

-- binds for hyprsunset
hl.bind("ALT + H", hl.dsp.exec_cmd("hyprctl hyprsunset temperature +500"))
hl.bind("ALT + B", hl.dsp.exec_cmd("hyprctl hyprsunset temperature -500"))

-- Perceived brightness (gamma) via media keys
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("hyprctl hyprsunset gamma +10"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("hyprctl hyprsunset gamma -10"))

-- Reset to current profile
hl.bind("ALT + SHIFT + H", hl.dsp.exec_cmd("hyprctl hyprsunset identity"))
