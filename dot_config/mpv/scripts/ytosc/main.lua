-- ytosc: YouTube-style OSC for mpv. See README.md.
local msg = require 'mp.msg'
local C = require 'config'
local A = require 'anim'
local S = require 'state'
local T = require 'theme'
local Lay = require 'layout'
local Menus = require 'menus'
local Openers = require 'openers'
local Thumb = require 'thumb'
local R = require 'render'
local Input = require 'input'
local Keys = require 'keys'
require 'actions'

local overlay = mp.create_osd_overlay("ass-events")
local overlay_shown = false
local timer, interval
local dirty, last_render = true, 0

local function render(now)
    local w, h = mp.get_osd_size()
    if not w or w == 0 or h == 0 then return end
    S.w, S.h = w, h
    S.layout = Lay.build(S, C)
    Thumb.sync(S.layout)
    local data = R.build(S, C, T, now)
    if data == "" then
        if overlay_shown then overlay:remove(); overlay_shown = false end
    else
        overlay.res_x, overlay.res_y, overlay.data = w, h, data
        overlay:update()
        overlay_shown = true
    end
    dirty, last_render = false, now
end

local function schedule(fast)
    local want = fast and (1 / 60) or 0.1
    if not timer then
        timer = mp.add_periodic_timer(want, function() S.cb.tick() end)
        interval = want
    elseif interval ~= want then
        timer:kill()
        timer.timeout = want
        timer:resume()
        interval = want
    elseif not timer:is_enabled() then
        timer:resume()
    end
end

local function set_visible(v)
    local now = mp.get_time()
    if S.visible_target ~= v then msg.verbose("controls " .. (v and "shown" or "hidden")) end
    S.visible_target = v
    A.to(S.vis, v and 1 or 0, v and 0.12 or 0.25, now)
    dirty = true
    schedule(true)
end

local function show()
    if S.idle then return end
    S.last_activity = mp.get_time()
    if not S.visible_target then set_visible(true) end
end

local function should_stay()
    if C.always_visible or S.drag or S.hover or S.menu or S.input or S.panel or S.strip then return true end
    if S.paused and not C.hide_when_paused then return true end
    return false
end

function S.cb.tick()
    local now = mp.get_time()
    local anim_on = A.step(now)
    local theme_on = T.step(now)

    if S.visible_target and not should_stay() and now - S.last_activity > C.hide_timeout then
        set_visible(false)
    end
    if S.toast and now > S.toast.t_end then S.toast = nil; dirty = true end
    local rip = false
    if S.ripple then
        if now - S.ripple.t0 > 0.55 then S.ripple = nil else rip = true end
        dirty = true
    end
    if anim_on or theme_on then dirty = true end

    local fast = anim_on or theme_on or rip or S.drag ~= nil or S.toast ~= nil
    if dirty and (fast or now - last_render >= 0.1) then render(now) end

    local keep_line = C.progress_line and not S.idle and (S.dur or 0) > 0
    if not S.visible_target and S.vis.v <= 0.001 and not S.toast and S.pending == "" and not anim_on and not rip
        and not keep_line then
        if overlay_shown and not S.idle then overlay:remove(); overlay_shown = false end
        if timer then timer:kill() end
        return
    end
    schedule(fast)
end

S.cb.show = show
S.cb.dirty = function() dirty = true end
S.cb.wake = function() dirty = true; schedule(true) end

---------------------------------------------------------------- properties
local function observe(name, kind, fn)
    mp.observe_property(name, kind, function(_, v)
        fn(v)
        if S.visible_target or S.vis.v > 0.001 or C.progress_line then dirty = true end
    end)
end

local function update_next()
    S.has_next = S.pl_pos >= 0 and S.pl_pos + 1 < S.pl_count
end

observe("time-pos", "number", function(v) S.pos = v or 0 end)
observe("duration", "number", function(v) S.dur = v or 0 end)
observe("pause", "bool", function(v) S.paused = v and true or false; show() end)
observe("volume", "number", function(v) S.volume = v or 0 end)
observe("volume-max", "number", function(v) S.volume_max = v or 100 end)
observe("mute", "bool", function(v) S.mute = v and true or false end)
observe("fullscreen", "bool", function(v) S.fullscreen = v and true or false end)
observe("chapter-list", "native", function(v) S.chapters = v or {} end)
observe("playlist-pos", "number", function(v) S.pl_pos = v or -1; update_next() end)
observe("playlist-count", "number", function(v) S.pl_count = v or 0; update_next() end)
observe("osd-dimensions", "native", function() end)
local function update_sub()
    local n = 0
    for _, t in ipairs(S.tracks) do if t.type == "sub" then n = n + 1 end end
    S.sub_count = n
    S.sub_on = (S.sid and S.sub_visible) and true or false
end
observe("track-list", "native", function(v) S.tracks = v or {}; update_sub() end)
observe("sid", "native", function(v) S.sid = v or false; update_sub() end)
observe("aid", "native", function(v) S.aid = v or false end)
observe("vid", "native", function(v) S.vid = v or false end)
observe("sub-visibility", "bool", function(v) S.sub_visible = v and true or false; update_sub() end)
observe("chapter", "number", function(v) S.chapter = v or -1 end)
observe("demuxer-cache-state", "native", function(v)
    local r = {}
    if v and v["seekable-ranges"] then
        for _, x in ipairs(v["seekable-ranges"]) do r[#r + 1] = { s = x["start"], e = x["end"] } end
    end
    S.cache = r
end)
observe("idle-active", "bool", function(v)
    S.idle = v and true or false
    if S.idle then set_visible(false); S.cb.wake() end
end)
observe("playlist", "native", function(v) S.playlist = v or {} end)
observe("media-title", "string", function(v) S.title = v or "" end)
observe("border", "bool", function(v) S.border = v ~= false end)

mp.register_event("file-loaded", function()
    show()
    Openers.record()
end)
mp.register_script_message("open", function(path) if path then Openers.open_paths({ path }, false) end end)
mp.register_script_message("append", function(path) if path then Openers.open_paths({ path }, true) end end)
mp.register_script_message("open-dir", function(path) if path then Openers.open_dir(path, false) end end)
mp.register_script_message("reload-colors", function()
    if T.reload(false) then S.cb.wake() end
end)
mp.add_periodic_timer(1, function()
    if T.poll() then S.cb.wake() end
end)

------------------------------------------------------------------- startup
A.set(S.bar_h, 3 * C.scale)
if C.always_visible then mp.set_property("cursor-autohide", "no") end
Openers.load_history()
T.init()
Keys.init()
Input.init()

if mp.get_property_native("osc") then
    msg.warn("mpv's built-in OSC is enabled; set osc=no (and osd-bar=no) in mpv.conf")
end
msg.verbose("ytosc loaded")
