-- Playlist panel (YouTube "Up next" style): list, filter, remove, reorder.
local U = require 'util'
local S = require 'state'
local A = require 'anim'
local TI = require 'textinput'

local P = {}
local KEYS = { "UP", "DOWN", "ENTER", "KP_ENTER", "Alt+j", "Alt+k", "d", "/", "j", "k", "l", "g", "G", "ESC", "SPACE" }

local function title_of(e)
    if e.title and e.title ~= "" then return e.title end
    local f = e.filename or ""
    if f:match("^%a[%w+.-]*://") then return f end
    return ((f:match("([^/]+)$") or f):gsub("%.%w+$", ""))
end

-- filtered entries: { idx = original 1-based index, title, current }
function P.entries()
    local list = {}
    local low = (S.panel and S.panel.filter or ""):lower()
    for i, e in ipairs(S.playlist) do
        local t = title_of(e)
        if low == "" or t:lower():find(low, 1, true) then
            list[#list + 1] = { idx = i, title = t, current = e.current and true or false }
        end
    end
    return list
end

function P.is_open() return S.panel ~= nil end

function P.open()
    require('menus').close()
    require('strip').close()
    if S.panel then return end
    S.panel = { sel = 1, scroll = 0, filter = "", d_t = 0, ensure = true }
    for i, e in ipairs(P.entries()) do
        if e.current then S.panel.sel = i end
    end
    for _, k in ipairs(KEYS) do
        mp.add_forced_key_binding(k, "ytosc-pl-" .. k, function() P.on_key(k) end, { repeatable = true })
    end
    A.set(S.panel_a, 0)
    A.to(S.panel_a, 1, 0.15, mp.get_time())
    S.cb.show()
    S.cb.wake()
end

function P.close()
    if not S.panel then return end
    if S.input then TI.close() end
    for _, k in ipairs(KEYS) do mp.remove_key_binding("ytosc-pl-" .. k) end
    S.panel, S.panel_geo = nil, nil
    S.cb.wake()
end

function P.toggle()
    if S.panel then P.close() else P.open() end
end

function P.set_sel(i)
    if S.panel and S.panel.sel ~= i then S.panel.sel = i; S.cb.wake() end
end

function P.scroll(d)
    if not S.panel then return end
    S.panel.scroll = math.max(0, S.panel.scroll + d * 3)
    S.cb.wake()
end

function P.play(i)
    local e = P.entries()[i]
    if e then mp.commandv("playlist-play-index", tostring(e.idx - 1)) end
end

function P.remove(i)
    local e = P.entries()[i]
    if e then mp.commandv("playlist-remove", tostring(e.idx - 1)) end
end

function P.move(i, delta)
    local p = S.panel
    local e = P.entries()[i]
    if not e or p.filter ~= "" then return end
    local i0 = e.idx - 1
    if delta > 0 and e.idx < #S.playlist then
        mp.commandv("playlist-move", tostring(i0), tostring(i0 + 2))
        p.sel = i + 1
    elseif delta < 0 and i0 > 0 then
        mp.commandv("playlist-move", tostring(i0), tostring(i0 - 1))
        p.sel = i - 1
    end
    p.ensure = true
end

function P.filter()
    local p = S.panel
    if not p then return end
    TI.open({ prompt = "/", text = p.filter,
        on_change = function(t) p.filter, p.sel, p.scroll = t, 1, 0 end,
        on_submit = function() end,
        on_cancel = function() p.filter, p.sel, p.scroll = "", 1, 0 end })
end

function P.on_key(tok)
    if S.input_focus then TI.key_token(tok); return end
    local p = S.panel
    if not p then return end
    local n = #P.entries()
    if tok == "j" or tok == "DOWN" then p.sel = U.clamp(p.sel + 1, 1, math.max(n, 1)); p.ensure = true
    elseif tok == "k" or tok == "UP" then p.sel = U.clamp(p.sel - 1, 1, math.max(n, 1)); p.ensure = true
    elseif tok == "G" then p.sel = math.max(n, 1); p.ensure = true
    elseif tok == "g" then p.sel = 1; p.ensure = true
    elseif tok == "ENTER" or tok == "KP_ENTER" or tok == "l" or tok == "SPACE" then P.play(p.sel)
    elseif tok == "d" then
        local now = mp.get_time()
        if now - p.d_t < 0.6 then P.remove(p.sel); p.d_t = 0 else p.d_t = now end
    elseif tok == "Alt+j" then P.move(p.sel, 1)
    elseif tok == "Alt+k" then P.move(p.sel, -1)
    elseif tok == "/" then P.filter()
    elseif tok == "ESC" then
        if p.filter ~= "" then p.filter, p.sel, p.scroll = "", 1, 0 else P.close() end
    end
    S.cb.wake()
end

function P.geometry(S_, C)
    local s, p = C.scale, S.panel
    local W = 360 * s
    local x2 = S_.w - 12 * s
    local x1 = x2 - W
    local y1 = 56 * s
    local y2 = S_.h - (4 + 48 + 22) * s
    local header, ih = 104 * s, 48 * s
    local list = P.entries()
    local nvis = math.max(1, math.floor((y2 - y1 - header - 8 * s) / ih))
    p.sel = U.clamp(p.sel, 1, math.max(#list, 1))
    if p.ensure then
        if p.sel < p.scroll + 1 then p.scroll = p.sel - 1
        elseif p.sel > p.scroll + nvis then p.scroll = p.sel - nvis end
        p.ensure = false
    end
    p.scroll = U.clamp(p.scroll, 0, math.max(0, #list - nvis))

    local py1, py2 = y1 + 62 * s, y1 + 94 * s
    local pills = {
        { id = "pl_open", label = "Open", x1 = x1 + 16 * s, x2 = x1 + 92 * s },
        { id = "pl_shuffle", label = "Shuffle", x1 = x1 + 100 * s, x2 = x1 + 190 * s },
        { id = "pl_loop", label = "Loop", x1 = x1 + 198 * s, x2 = x1 + 262 * s,
          active = (mp.get_property("loop-playlist") or "no") ~= "no" },
    }
    local g = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, header = header, ih = ih, list = list, nvis = nvis,
        scroll = p.scroll, sel = p.sel, pills = pills, py1 = py1, py2 = py2, total = #S.playlist }
    S_.panel_geo = g

    local regions = {}
    for _, pl in ipairs(pills) do
        regions[#regions + 1] = { id = pl.id, x1 = pl.x1, x2 = pl.x2, y1 = py1, y2 = py2 }
    end
    regions[#regions + 1] = { id = "pl_close", x1 = x2 - 48 * s, x2 = x2 - 8 * s, y1 = y1 + 8 * s, y2 = y1 + 48 * s }
    for row = 1, nvis do
        local idx = p.scroll + row
        if idx > #list then break end
        local ry = y1 + header + (row - 1) * ih
        regions[#regions + 1] = { id = "pl_item:" .. idx, x1 = x1, x2 = x2, y1 = ry, y2 = ry + ih }
    end
    regions[#regions + 1] = { id = "pl_bg", x1 = x1, x2 = x2, y1 = y1, y2 = y2 }
    return { regions = regions }
end

return P
