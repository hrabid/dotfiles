local utils = require 'mp.utils'
local msg = require 'mp.msg'
local U = require 'util'
local C = require 'config'

local T = {}

-- fallback palette: YouTube dark
local FALLBACK = {
    primary = "ff0000", on_primary = "ffffff",
    surface = "212121", surface_container = "3d3d3d",
    on_surface = "ffffff", on_surface_variant = "aaaaaa",
    surface_variant = "4d4d4d", outline = "717171",
    error = "ff6b6b", scrim = "000000",
}

local function hex2rgb(h)
    local r, g, b = tostring(h):match("^#?(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
end

local function copy(t)
    local o = {}
    for k, v in pairs(t) do o[k] = { v[1], v[2], v[3] } end
    return o
end

local function defaults()
    local t = {}
    for k, v in pairs(FALLBACK) do t[k] = hex2rgb(v) end
    return t
end

local cur = defaults()
local from, target, fade_t0
local path, last_mtime, last_size

local function parse(p)
    local f = io.open(p, "r")
    if not f then return nil end
    local out, n = {}, 0
    for line in f:lines() do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*(#?%x+)%s*$")
        if k and FALLBACK[k] then
            local rgb = hex2rgb(v)
            if rgb then out[k] = rgb; n = n + 1 else msg.warn("bad color for " .. k .. ": " .. v) end
        end
    end
    f:close()
    return out, n
end

local function lum(c)
    local function ch(x)
        x = x / 255
        return x <= 0.03928 and x / 12.92 or ((x + 0.055) / 1.055) ^ 2.4
    end
    return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
end

local function contrast_check(t)
    local a, b = lum(t.on_surface), lum(t.surface)
    if a < b then a, b = b, a end
    local ratio = (a + 0.05) / (b + 0.05)
    if ratio < 4.5 then msg.warn(string.format("low contrast between on_surface and surface (%.1f:1)", ratio)) end
end

function T.reload(initial)
    if not path then return false end
    local parsed, n = parse(path)
    if not parsed or n == 0 then
        if parsed then msg.warn("colors file has no valid entries, keeping previous palette") end
        return false
    end
    local tgt = defaults()
    for k, v in pairs(parsed) do tgt[k] = v end
    contrast_check(tgt)
    if initial then
        cur, fade_t0 = tgt, nil
    else
        from, target, fade_t0 = copy(cur), tgt, mp.get_time()
    end
    return true
end

function T.init()
    path = mp.command_native({ "expand-path", C.colors_file })
    local info = utils.file_info(path)
    if info and info.is_file then
        last_mtime, last_size = info.mtime, info.size
        T.reload(true)
    end
end

-- poll the colors file (works with any number of mpv windows)
function T.poll()
    if not path then return false end
    local info = utils.file_info(path)
    if not info or not info.is_file then return false end
    if info.mtime == last_mtime and info.size == last_size then return false end
    last_mtime, last_size = info.mtime, info.size
    return T.reload(false)
end

-- advance the crossfade; returns true while it needs redraws
function T.step(now)
    if not fade_t0 then return false end
    local p = (now - fade_t0) / 0.3
    if p >= 1 then
        cur, fade_t0 = target, nil
        return true
    end
    local e = U.ease(p)
    local nxt = {}
    for k, a in pairs(from) do
        local b = target[k]
        nxt[k] = { U.lerp(a[1], b[1], e), U.lerp(a[2], b[2], e), U.lerp(a[3], b[3], e) }
    end
    cur = nxt
    return true
end

-- ASS color string (BGR)
function T.ass(key)
    local c = cur[key] or cur.on_surface
    return string.format("&H%02X%02X%02X&", math.floor(c[3] + 0.5), math.floor(c[2] + 0.5), math.floor(c[1] + 0.5))
end

return T
