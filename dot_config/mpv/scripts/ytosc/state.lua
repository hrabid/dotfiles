local A = require 'anim'

local S = {
    w = 0, h = 0,
    pos = 0, dur = 0,
    paused = false, idle = false,
    volume = 100, volume_max = 100, mute = false,
    fullscreen = false,
    chapters = {}, cache = {},
    pl_pos = -1, pl_count = 0, has_next = false,
    remaining = false,
    mouse = { x = 0, y = 0, inside = false },
    hover = nil,        -- id of region under the cursor
    drag = nil,         -- "seek" | "volume"
    scrub_frac = nil,
    toast = nil,        -- { text, t_end, pos }
    pending = "",       -- pending key sequence indicator
    input_focus = false,
    visible_target = false,
    last_activity = 0,
    layout = nil,
    tracks = {}, sid = false, aid = false, vid = false,
    sub_count = 0, sub_visible = true, sub_on = false,
    chapter = -1,          -- current chapter index (0-based)
    playlist = {},
    view = "default",       -- default | theater | mini
    title = "", border = true,
    ripple = nil,           -- { x, y, t0 } double-click seek feedback
    panel = nil, panel_geo = nil,   -- playlist panel
    strip = nil, strip_geo = nil,   -- more-videos strip
    menu = nil,            -- { stack = { {id, sel, scroll}, ... } }
    menu_geo = nil,
    input = nil,           -- text input widget { prompt, text, caret, on_submit }
    playlist = {}, pl_title = nil, shuffled = false,
    panel = nil, panel_geo = nil,
    strip = nil, strip_geo = nil,
    recent = {},
    -- callbacks, set by main.lua
    cb = { show = function() end, dirty = function() end, wake = function() end },
}

S.vis = A.new(0)    -- controls opacity 0..1
S.bar_h = A.new(3)  -- seekbar thickness (px), set properly in main
S.dot_r = A.new(0)  -- scrubber dot radius
S.vol_w = A.new(0)  -- volume slider width
S.menu_a = A.new(0) -- menu fade-in
S.panel_a = A.new(0) -- playlist panel fade-in
S.panel_a = A.new(0)
S.strip_a = A.new(0)

return S
