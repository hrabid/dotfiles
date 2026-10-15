-- Icons: Google Material Icons (Apache License 2.0), pre-converted to ASS drawings in icondata.lua.
-- Each icon is drawn on a 24x24 grid, scaled to size `s`, centered at (cx, cy), optionally rotated.
local D = require 'draw'
local DATA = require 'icondata'

local I = {}

local cache, cache_n = {}, 0

local function path(name, cx, cy, s, angle)
    local key = string.format("%s:%.1f:%.1f:%.1f:%.0f", name, cx, cy, s, angle or 0)
    local hit = cache[key]
    if hit then return hit end
    local u, ox, oy = s / 24, cx - s / 2, cy - s / 2
    local ca, sa = 1, 0
    if angle and angle ~= 0 then
        local r = math.rad(angle)
        ca, sa = math.cos(r), math.sin(r)
    end
    local out = DATA[name]:gsub("(%-?[%d%.]+) (%-?[%d%.]+)", function(x, y)
        x, y = tonumber(x) - 12, tonumber(y) - 12
        local rx, ry = x * ca - y * sa, x * sa + y * ca
        return string.format("%.1f %.1f", ox + (rx + 12) * u, oy + (ry + 12) * u)
    end)
    if cache_n > 400 then cache, cache_n = {}, 0 end
    cache[key] = out
    cache_n = cache_n + 1
    return out
end

local function draw(ev, name, cx, cy, s, col, op, angle)
    ev[#ev + 1] = D.shape(path(name, cx, cy, s, angle), col, op)
end

function I.play(ev, cx, cy, s, col, op) draw(ev, "play_arrow", cx, cy, s, col, op) end
function I.pause(ev, cx, cy, s, col, op) draw(ev, "pause", cx, cy, s, col, op) end
function I.next(ev, cx, cy, s, col, op) draw(ev, "skip_next", cx, cy, s, col, op) end

-- level: 0..1 volume fraction; muted draws the crossed-out speaker
function I.volume(ev, cx, cy, s, col, op, level, muted)
    local name = muted and "volume_off" or level <= 0 and "volume_mute" or level < 0.5 and "volume_down" or "volume_up"
    draw(ev, name, cx, cy, s, col, op)
end

function I.fullscreen(ev, cx, cy, s, col, op, is_fs)
    draw(ev, is_fs and "fullscreen_exit" or "fullscreen", cx, cy, s, col, op)
end

function I.check(ev, cx, cy, s, col, op) draw(ev, "check", cx, cy, s, col, op) end

function I.chevron(ev, cx, cy, s, col, op, dir)
    local name = dir == "left" and "chevron_left" or dir == "up" and "expand_less" or dir == "down" and "expand_more" or "chevron_right"
    draw(ev, name, cx, cy, s, col, op)
end

-- closed-caption badge; `active` adds the accent underline (like YouTube's red bar)
function I.cc(ev, cx, cy, s, col, op, font, active, accent)
    draw(ev, "closed_caption", cx, cy, s, col, op)
    if active then
        local u = s / 24
        ev[#ev + 1] = D.shape(D.rrect(cx - 8 * u, cy + 10.2 * u, cx + 8 * u, cy + 11.8 * u, 0.8 * u), accent, op)
    end
end

function I.gear(ev, cx, cy, s, col, op, angle) draw(ev, "settings", cx, cy, s, col, op, angle) end
function I.list(ev, cx, cy, s, col, op) draw(ev, "format_list_bulleted", cx, cy, s, col, op) end
function I.folder(ev, cx, cy, s, col, op) draw(ev, "folder_open", cx, cy, s, col, op) end
function I.view(ev, cx, cy, s, col, op) draw(ev, "crop_16_9", cx, cy, s, col, op) end
function I.minimize(ev, cx, cy, s, col, op) draw(ev, "remove", cx, cy, s, col, op) end
function I.maximize(ev, cx, cy, s, col, op) draw(ev, "crop_square", cx, cy, s, col, op) end
function I.close(ev, cx, cy, s, col, op) draw(ev, "close", cx, cy, s, col, op) end

return I
