-- View modes: default / theater / miniplayer. Hyprland is driven through hyprctl; other
-- compositors get a miniplayer fallback (ontop + smaller window) and no theater mode.
local utils = require 'mp.utils'
local S = require 'state'
local C = require 'config'

local V = { getenv = os.getenv }

local function toast(t) require('actions').toast(t) end

function V.available() return V.getenv("HYPRLAND_INSTANCE_SIGNATURE") ~= nil end

local function run(args, cb)
    mp.command_native_async({ name = "subprocess", args = args, capture_stdout = true, playback_only = false },
        function(ok, res) cb((ok and res and res.status == 0) and (res.stdout or "") or nil) end)
end

local function json(args, cb)
    run(args, function(out) cb(out and utils.parse_json(out) or nil) end)
end

-- this mpv's own window, matched by pid so several mpv windows never get mixed up
local function own_client(cb)
    json({ "hyprctl", "clients", "-j" }, function(list)
        local pid = mp.get_property_number("pid")
        for _, c in ipairs(list or {}) do
            if c.pid == pid then cb(c); return end
        end
        cb(nil)
    end)
end

local function monitor_of(c, cb)
    json({ "hyprctl", "monitors", "-j" }, function(list)
        for _, m in ipairs(list or {}) do
            if m.id == c.monitor then cb(m); return end
        end
        cb(list and list[1])
    end)
end

local function batch(cmds)
    run({ "hyprctl", "--batch", table.concat(cmds, " ; ") }, function() end)
end

local function parse_size()
    local w, h = C.mini_size:match("^(%d+)x(%d+)$")
    return tonumber(w) or 480, tonumber(h) or 270
end

local function mini_pos(m, w, h)
    local sc = m.scale or 1
    local lw, lh = m.width / sc, m.height / sc
    local r = m.reserved or { 0, 0, 0, 0 }
    local mg = C.mini_margin
    local x = C.mini_corner:find("left") and (m.x + r[1] + mg) or (m.x + lw - r[3] - w - mg)
    local y = C.mini_corner:find("top") and (m.y + r[2] + mg) or (m.y + lh - r[4] - h - mg)
    return math.floor(x), math.floor(y)
end

-- commands that undo the mode we are currently in
local function leave_cmds(c, addr)
    local cmds = {}
    if S.view == "theater" then
        if c.fullscreen == 1 then cmds[#cmds + 1] = "dispatch fullscreen 1" end
    elseif S.view == "mini" and V.saved then
        local sv = V.saved
        if c.pinned and not sv.pinned then cmds[#cmds + 1] = "dispatch pin " .. addr end
        if sv.floating then
            cmds[#cmds + 1] = string.format("dispatch resizewindowpixel exact %d %d,%s", sv.size[1], sv.size[2], addr)
            cmds[#cmds + 1] = string.format("dispatch movewindowpixel exact %d %d,%s", sv.at[1], sv.at[2], addr)
        elseif c.floating then
            cmds[#cmds + 1] = "dispatch settiled " .. addr
        end
    end
    return cmds
end

local function fallback(mode)
    if mode == "theater" then toast("Theater mode needs Hyprland"); return end
    if mode == "mini" then
        local vw = mp.get_property_number("dwidth") or 1280
        V.fb = { scale = mp.get_property_number("window-scale", 1), ontop = mp.get_property_bool("ontop") }
        mp.set_property_number("window-scale", (parse_size()) / vw)
        mp.set_property_bool("ontop", true)
        S.view = "mini"
    else
        if V.fb then
            mp.set_property_number("window-scale", V.fb.scale)
            mp.set_property_bool("ontop", V.fb.ontop)
            V.fb = nil
        end
        S.view = "default"
    end
    S.cb.wake()
end

function V.set(mode)
    if mode == S.view then return end
    if mode ~= "default" and mp.get_property_bool("fullscreen") then mp.set_property_bool("fullscreen", false) end
    if not V.available() then fallback(mode); return end
    own_client(function(c)
        if not c then toast("Could not find this window in Hyprland"); return end
        local addr = "address:" .. c.address
        local cmds = leave_cmds(c, addr)
        local function finish(extra)
            local all = { "dispatch focuswindow " .. addr }
            for _, x in ipairs(cmds) do all[#all + 1] = x end
            for _, x in ipairs(extra) do all[#all + 1] = x end
            if #all > 1 then batch(all) end
            S.view = mode
            S.cb.wake()
        end
        if mode == "theater" then
            -- leaving mini first leaves the window unmaximized, so toggle maximize on
            finish((c.fullscreen == 1 and S.view ~= "theater") and {} or { "dispatch fullscreen 1" })
        elseif mode == "mini" then
            if S.view ~= "mini" then
                V.saved = { floating = c.floating, pinned = c.pinned, at = c.at, size = c.size }
            end
            monitor_of(c, function(m)
                local w, h = parse_size()
                local extra = {}
                if not c.floating then extra[#extra + 1] = "dispatch setfloating " .. addr end
                if not c.pinned then extra[#extra + 1] = "dispatch pin " .. addr end
                extra[#extra + 1] = string.format("dispatch resizewindowpixel exact %d %d,%s", w, h, addr)
                if m then
                    local x, y = mini_pos(m, w, h)
                    extra[#extra + 1] = string.format("dispatch movewindowpixel exact %d %d,%s", x, y, addr)
                end
                finish(extra)
            end)
        else
            finish({})
        end
    end)
end

function V.toggle(mode)
    V.set(S.view == mode and "default" or mode)
end

return V
