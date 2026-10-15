local U = require 'util'
local S = require 'state'
local C = require 'config'
local A = require 'anim'
local L = require 'layout'
local Act = require 'actions'
local Menus = require 'menus'
local Panel = require 'panel'
local Strip = require 'strip'

local I = {}

local press, click_timer
local last_seek = 0
local dbl_accum, dbl_dir, dbl_t = 0, 0, 0

-- mpv returns x, y (and hover) as plain numbers; some builds return a table instead
local function mpos()
    local a, b = mp.get_mouse_pos()
    if type(a) == "table" then return a.x or 0, a.y or 0 end
    return a or 0, b or 0
end

local function relayout()
    local w, h = mp.get_osd_size()
    if w and w > 0 and h > 0 then
        S.w, S.h = w, h
        S.layout = L.build(S, C)
    end
    return S.layout
end

-- true when the mouse is somewhere that should reveal the controls
local function in_reveal_zone(y)
    if C.reveal_area == "window" then return true end
    local s = C.scale
    if y >= S.h - C.reveal_height * s then return true end
    local lay = S.layout
    return lay ~= nil and lay.wc ~= nil and y <= 56 * s   -- title bar buttons of a borderless window
end

local function hit(x, y)
    local lay = S.layout or relayout()
    if not lay then return nil end
    return L.hit(lay, x, y)
end

local function update_targets(id)
    local s, now = C.scale, mp.get_time()
    local on_bar = (id == "seekbar") or S.drag == "seek"
    A.to(S.bar_h, on_bar and 6 * s or 3 * s, 0.12, now)
    A.to(S.dot_r, on_bar and 7 * s or 0, 0.12, now)
    local on_vol = id == "volume_icon" or id == "volume_slider" or S.drag == "volume"
    A.to(S.vol_w, on_vol and 64 * s or 0, 0.15, now)
end

local function seek_from_x(x, final)
    local lay = S.layout
    local dur = S.dur or 0
    if not lay or dur <= 0 then return end
    local frac = U.clamp((x - lay.bar.x1) / (lay.bar.x2 - lay.bar.x1), 0, 1)
    S.scrub_frac = frac
    local now = mp.get_time()
    if final then
        mp.commandv("seek", tostring(frac * dur), "absolute+exact")
    elseif C.scrub_mode == "live" and now - last_seek > 0.06 then
        last_seek = now
        mp.commandv("seek", tostring(frac * dur), "absolute+keyframes")
    end
end

local function volume_from_x(x)
    local lay = S.layout
    if not lay or not lay.vol then return end
    local frac = U.clamp((x - lay.vol.x1) / (lay.vol.x2 - lay.vol.x1), 0, 1)
    mp.set_property_number("volume", frac * S.volume_max)
    mp.set_property_bool("mute", false)
end

local function activate(id)
    local n = id:match("^menu_item:(%d+)$")
    if n then Menus.activate(tonumber(n)); return end
    local pl = id:match("^pl_item:(%d+)$")
    if pl then Panel.play(tonumber(pl)); return end
    local sc = id:match("^strip_card:(%d+)$")
    if sc then Strip.activate(tonumber(sc)); return end
    if id == "pl_close" then Panel.close()
    elseif id == "pl_open" or id == "open" or id == "idle_open" then Menus.open("open")
    elseif id == "pl_shuffle" then mp.commandv("playlist-shuffle")
    elseif id == "pl_loop" then
        mp.set_property("loop-playlist", (mp.get_property("loop-playlist") or "no") == "no" and "inf" or "no")
    elseif id == "view" then Menus.open("view")
    elseif id == "wc_min" then mp.set_property_bool("window-minimized", true)
    elseif id == "wc_max" then mp.commandv("cycle", "window-maximized")
    elseif id == "wc_close" or id == "mini_close" then mp.commandv("quit")
    elseif id == "view_expand" then require('view').set("default")
    elseif id == "playlist" then Panel.toggle()
    elseif id == "strip_toggle" then Strip.toggle()
    elseif id == "strip_prev" then Strip.scroll(-1)
    elseif id == "strip_next" then Strip.scroll(1)
    elseif id == "menu_back" then Menus.back()
    elseif id == "settings" then Menus.toggle()
    elseif id == "cc" then Act.cc_toggle()
    elseif id == "chapter" then Menus.open("chapters")
    elseif id == "play" then Act.table.pause.fn()
    elseif id == "next" then Act.table.playlist_next.fn()
    elseif id == "volume_icon" then Act.table.mute.fn()
    elseif id == "time" then Act.table.toggle_remaining.fn()
    elseif id == "fullscreen" then Act.table.fullscreen.fn() end
end

local function on_move()
    local x, y = mpos()
    S.mouse.x, S.mouse.y, S.mouse.inside = x, y, true
    relayout()
    if in_reveal_zone(y) then
        S.cb.show()
    else
        -- outside the zone: do not reveal, and hide quickly if the controls were showing
        S.last_activity = math.min(S.last_activity, mp.get_time() - C.hide_timeout + 0.4)
    end
    local id = hit(x, y)
    S.hover = id
    local mi = id and id:match("^menu_item:(%d+)$")
    if mi then Menus.set_sel(tonumber(mi)) end
    local pi = id and id:match("^pl_item:(%d+)$")
    if pi then Panel.set_sel(tonumber(pi)) end
    local si = id and id:match("^strip_card:(%d+)$")
    if si then Strip.set_sel(tonumber(si)) end
    update_targets(id)
    if S.drag == "seek" then seek_from_x(x, false)
    elseif S.drag == "volume" then volume_from_x(x) end
    S.cb.wake()
end

local function on_leave()
    S.mouse.inside = false
    S.hover = nil
    -- the mouse left the window: hide the controls quickly
    S.last_activity = math.min(S.last_activity, mp.get_time() - C.hide_timeout + 0.4)
    if not S.drag then update_targets(nil) end
    S.cb.wake()
end

local function on_lmb(e)
    local x, y = mpos()
    local id = hit(x, y)
    if e.event == "down" then
        if in_reveal_zone(y) then S.cb.show() end
        if (S.menu or S.strip) and not (id and (id:match("^menu_") or id:match("^strip_") or id == "settings")) then
            Menus.close()      -- click outside the popup closes it and is swallowed
            Strip.close()
            press = "swallow"
            S.cb.wake()
            return
        end
        press = id
        if id == "seekbar" then
            S.drag = "seek"
            Act.push_undo()
            seek_from_x(x, false)
        elseif id == "volume_slider" then
            S.drag = "volume"
            volume_from_x(x)
        end
    elseif e.event == "up" then
        if S.drag == "seek" then
            seek_from_x(x, true)
            S.drag, S.scrub_frac = nil, nil
        elseif S.drag == "volume" then
            S.drag = nil
        elseif id and id == press then
            activate(id)
        elseif not id and press == nil then
            -- plain click on the video: pause, unless a double click follows
            if click_timer then click_timer:kill() end
            click_timer = mp.add_timeout(0.25, function()
                click_timer = nil
                Act.table.pause.fn()
            end)
        end
        press = nil
        update_targets(id)
    end
    S.cb.wake()
end

local function on_dbl()
    local x, y = mpos()
    if hit(x, y) or S.menu or S.input or S.strip then return end
    if click_timer then click_timer:kill(); click_timer = nil end
    local third = S.w / 3
    if x < third or x > 2 * third then
        local dir = x < third and -1 or 1
        local now = mp.get_time()
        if dir == dbl_dir and now - dbl_t < 0.8 then dbl_accum = dbl_accum + C.double_click_seek
        else dbl_accum = C.double_click_seek end
        dbl_dir, dbl_t = dir, now
        S.ripple = { x = x, y = y, t0 = now }
        Act.seek_rel(dir * C.double_click_seek)
        Act.toast(string.format("%d seconds", dbl_accum), dir < 0 and "left" or "right")
    else
        Act.table.fullscreen.fn()
    end
end

local function on_wheel(dir)
    local x, y = mpos()
    if in_reveal_zone(y) then S.cb.show() end
    local id = hit(x, y)
    if id and id:match("^menu_") then Menus.move(-dir); return end
    if id and id:match("^pl_") then Panel.scroll(-dir); return end
    if id and id:match("^strip_") then Strip.scroll(-dir); return end
    if id == "seekbar" then Act.seek_rel(dir * C.wheel_seek)
    else Act.volume_add(dir * C.volume_step) end
end

function I.init()
    mp.set_key_bindings({
        { "mouse_move", on_move },
        { "mouse_leave", on_leave },
    }, "ytosc-hover", "force")
    mp.enable_key_bindings("ytosc-hover", "allow-hide-cursor")
    mp.add_forced_key_binding("mbtn_left", "ytosc-lmb", on_lmb, { complex = true })
    mp.add_forced_key_binding("mbtn_left_dbl", "ytosc-lmb-dbl", on_dbl)
    mp.add_forced_key_binding("wheel_up", "ytosc-wheel-up", function() on_wheel(1) end)
    mp.add_forced_key_binding("wheel_down", "ytosc-wheel-down", function() on_wheel(-1) end)
end

-- exposed for tests
I._on_move, I._on_lmb, I._on_dbl, I._on_wheel = on_move, on_lmb, on_dbl, on_wheel

return I
