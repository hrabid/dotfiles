-- YouTube-style settings popup: nested pages, radio lists, toggles, chapter list.
local U = require 'util'
local S = require 'state'
local A = require 'anim'
local TI = require 'textinput'

local M = {}
local NAV = { "UP", "DOWN", "LEFT", "RIGHT", "ENTER", "KP_ENTER", "BS" }
local PAGES = {}

------------------------------------------------------------------ helpers
local function toast(text) require('actions').toast(text) end

local function tracks(kind)
    local r = {}
    for _, t in ipairs(S.tracks) do
        if t.type == kind and not t.albumart then r[#r + 1] = t end
    end
    return r
end

local function track_label(t)
    if t.type == "video" then
        local w, h, fps = t["demux-w"], t["demux-h"], t["demux-fps"]
        if w and h then
            local s = string.format("%dx%d", w, h)
            if fps then s = s .. string.format(" %gfps", math.floor(fps * 100 + 0.5) / 100) end
            return s
        end
    end
    local parts = {}
    if t.lang then parts[#parts + 1] = t.lang end
    if t.title then parts[#parts + 1] = t.title end
    if #parts == 0 then parts[#parts + 1] = (t.codec and (t.codec .. " ") or "") .. "track " .. t.id end
    return table.concat(parts, " - ")
end

local function selected_label(kind, id)
    if not id then return "Off" end
    for _, t in ipairs(tracks(kind)) do
        if t.id == id then return track_label(t) end
    end
    return "On"
end

local function num_eq(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-3 end

local function norm_color(c)
    if not c then return "" end
    c = c:upper()
    if #c == 9 and c:sub(2, 3) == "FF" then c = "#" .. c:sub(4) end
    return c
end

local function fmt_speed(v) return tostring(math.floor(v * 100 + 0.5) / 100) .. "x" end

-- generic radio page: options = { {label, value}, ... }
local function radio(title, options, get, set)
    return function()
        local items, cur = {}, get()
        for _, o in ipairs(options) do
            local v = o[2]
            items[#items + 1] = {
                label = o[1], kind = "radio",
                checked = (cur == v) or num_eq(cur, v),
                on = function() set(v) end,
            }
        end
        return { title = title, items = items }
    end
end

local function option_label(options, cur)
    for _, o in ipairs(options) do
        if o[2] == cur or num_eq(o[2], cur) then return o[1] end
    end
    return nil
end

local function delay_page(title, prop)
    return function()
        local d = mp.get_property_number(prop, 0)
        local function bump(n) return function() mp.set_property_number(prop, d + n) end end
        return { title = string.format("%s: %+.1fs", title, d), items = {
            { label = "-100 ms", kind = "action", keep = true, on = bump(-0.1) },
            { label = "+100 ms", kind = "action", keep = true, on = bump(0.1) },
            { label = "Reset", kind = "action", keep = true, on = function() mp.set_property_number(prop, 0) end },
        } }
    end
end

----------------------------------------------------- subtitle option groups
local SUB = {}
SUB.font = { label = "Font", opts = { { "Sans", "sans-serif" }, { "Serif", "serif" }, { "Monospace", "monospace" } },
    get = function() return mp.get_property("sub-font") end,
    set = function(v) mp.set_property("sub-font", v) end }
SUB.size = { label = "Font size", opts = { { "Tiny", 25 }, { "Small", 40 }, { "Medium", 55 }, { "Large", 70 }, { "Huge", 90 } },
    get = function() return mp.get_property_number("sub-font-size", 55) end,
    set = function(v) mp.set_property_number("sub-font-size", v) end }
SUB.color = { label = "Text color", opts = {
        { "White", "#FFFFFF" }, { "Yellow", "#FFFF00" }, { "Green", "#00FF00" }, { "Cyan", "#00FFFF" },
        { "Blue", "#0000FF" }, { "Magenta", "#FF00FF" }, { "Red", "#FF0000" }, { "Black", "#000000" } },
    get = function() return norm_color(mp.get_property("sub-color")) end,
    set = function(v) mp.set_property("sub-color", v) end }
SUB.bg = { label = "Background opacity", opts = {
        { "0%", "#00000000" }, { "25%", "#40000000" }, { "50%", "#80000000" }, { "75%", "#BF000000" }, { "100%", "#FF000000" } },
    get = function() return (mp.get_property("sub-back-color") or ""):upper() end,
    set = function(v)
        mp.set_property("sub-back-color", v)
        mp.set_property("sub-border-style", v == "#00000000" and "outline-and-shadow" or "opaque-box")
    end }
SUB.edge = { label = "Edge style", opts = { { "None", "none" }, { "Outline", "outline" }, { "Drop shadow", "shadow" } },
    get = function()
        if mp.get_property_number("sub-border-size", 3) > 0 then return "outline" end
        if mp.get_property_number("sub-shadow-offset", 0) > 0 then return "shadow" end
        return "none"
    end,
    set = function(v)
        mp.set_property_number("sub-border-size", v == "outline" and 3 or 0)
        mp.set_property_number("sub-shadow-offset", v == "shadow" and 2 or 0)
    end }
SUB.pos = { label = "Position", opts = { { "Bottom", 100 }, { "Raised", 92 }, { "Higher", 80 }, { "Middle", 50 }, { "Top", 5 } },
    get = function() return mp.get_property_number("sub-pos", 100) end,
    set = function(v) mp.set_property_number("sub-pos", v) end }
local SUB_ORDER = { "font", "size", "color", "bg", "edge", "pos" }

local function sub_reset()
    mp.set_property("sub-font", "sans-serif")
    mp.set_property_number("sub-font-size", 55)
    mp.set_property("sub-color", "#FFFFFF")
    mp.set_property("sub-back-color", "#00000000")
    mp.set_property("sub-border-style", "outline-and-shadow")
    mp.set_property_number("sub-border-size", 3)
    mp.set_property_number("sub-shadow-offset", 0)
    mp.set_property_number("sub-pos", 100)
    mp.set_property_number("sub-delay", 0)
    mp.set_property("sub-ass-override", "yes")
end

for id, g in pairs(SUB) do PAGES["sub_" .. id] = radio(g.label, g.opts, g.get, g.set) end
PAGES.sub_delay = delay_page("Subtitle delay", "sub-delay")
PAGES.audio_delay = delay_page("Audio delay", "audio-delay")

PAGES.subopts = function()
    local items = {}
    for _, id in ipairs(SUB_ORDER) do
        local g = SUB[id]
        items[#items + 1] = { label = g.label, kind = "submenu", page = "sub_" .. id, value = option_label(g.opts, g.get()) }
    end
    items[#items + 1] = { label = "Delay", kind = "submenu", page = "sub_delay",
        value = string.format("%+.1fs", mp.get_property_number("sub-delay", 0)) }
    items[#items + 1] = { label = "Override embedded styling", kind = "toggle", keep = true,
        checked = mp.get_property("sub-ass-override") == "force",
        on = function()
            local on = mp.get_property("sub-ass-override") == "force"
            mp.set_property("sub-ass-override", on and "yes" or "force")
        end }
    items[#items + 1] = { label = "Reset to defaults", kind = "action", keep = true, on = sub_reset }
    return { title = "Options", items = items }
end

------------------------------------------------------------------- pages
local SPEEDS = { 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3 }
PAGES.speed = function()
    local cur = mp.get_property_number("speed", 1)
    local items = {}
    for _, v in ipairs(SPEEDS) do
        items[#items + 1] = { label = v == 1 and "Normal" or fmt_speed(v), kind = "radio", checked = num_eq(cur, v),
            on = function() mp.set_property_number("speed", v) end }
    end
    items[#items + 1] = { label = "Custom...", kind = "action", on = function()
        M.close()
        TI.open({ prompt = "Speed", on_submit = function(text)
            local n = tonumber(text)
            if n and n > 0 and n <= 100 then mp.set_property_number("speed", n) else toast("Invalid speed") end
        end })
    end }
    return { title = "Playback speed", items = items }
end

PAGES.subs = function()
    local items = {
        { label = "Off", kind = "radio", checked = not (S.sid and S.sub_visible),
          on = function() mp.set_property("sid", "no") end },
    }
    for _, t in ipairs(tracks("sub")) do
        items[#items + 1] = { label = track_label(t), kind = "radio", checked = (S.sid == t.id and S.sub_visible),
            on = function()
                mp.set_property_number("sid", t.id)
                mp.set_property_bool("sub-visibility", true)
            end }
    end
    items[#items + 1] = { label = "Options", kind = "submenu", page = "subopts" }
    return { title = "Subtitles/CC", items = items }
end

PAGES.audio = function()
    local items = {
        { label = "Off", kind = "radio", checked = not S.aid, on = function() mp.set_property("aid", "no") end },
    }
    for _, t in ipairs(tracks("audio")) do
        items[#items + 1] = { label = track_label(t), kind = "radio", checked = S.aid == t.id,
            on = function() mp.set_property_number("aid", t.id) end }
    end
    items[#items + 1] = { label = "Delay", kind = "submenu", page = "audio_delay",
        value = string.format("%+.1fs", mp.get_property_number("audio-delay", 0)) }
    return { title = "Audio", items = items }
end

PAGES.video = function()
    local items = {
        { label = "Auto", kind = "radio", checked = false, on = function() mp.set_property("vid", "auto") end },
    }
    for _, t in ipairs(tracks("video")) do
        items[#items + 1] = { label = track_label(t), kind = "radio", checked = S.vid == t.id,
            on = function() mp.set_property_number("vid", t.id) end }
    end
    return { title = "Video", items = items }
end

local ASPECT = { { "Default", -1 }, { "16:9", 16 / 9 }, { "4:3", 4 / 3 }, { "21:9", 21 / 9 }, { "1:1", 1 } }
PAGES.aspect = radio("Aspect ratio", ASPECT,
    function() return mp.get_property_number("video-aspect-override", -1) end,
    function(v) mp.set_property_number("video-aspect-override", v) end)

local function loop_state()
    if mp.get_property("loop-file") ~= "no" and mp.get_property("loop-file") ~= nil then return "file" end
    if mp.get_property("loop-playlist") ~= "no" and mp.get_property("loop-playlist") ~= nil then return "playlist" end
    return "none"
end
PAGES.loop = radio("Loop", { { "None", "none" }, { "Loop file", "file" }, { "Loop playlist", "playlist" } },
    loop_state,
    function(v)
        mp.set_property("loop-file", v == "file" and "inf" or "no")
        mp.set_property("loop-playlist", v == "playlist" and "inf" or "no")
    end)

PAGES.chapters = function()
    local items = {}
    for i, c in ipairs(S.chapters) do
        items[#items + 1] = {
            label = (c.title and c.title ~= "") and c.title or ("Chapter " .. i),
            value = U.fmt_time(c.time), kind = "radio", checked = (i - 1 == S.chapter),
            on = function() mp.set_property_number("chapter", i - 1) end,
        }
    end
    return { title = "Chapters", items = items }
end

PAGES.view = function()
    local V = require 'view'
    local function mode(m) return function() V.set(m) end end
    return { title = "View", items = {
        { label = "Default view", kind = "radio", checked = S.view == "default" and not S.fullscreen, on = mode("default") },
        { label = "Theater mode", kind = "radio", checked = S.view == "theater", on = mode("theater") },
        { label = "Miniplayer", kind = "radio", checked = S.view == "mini", on = mode("mini") },
        { label = "Fullscreen", kind = "radio", checked = S.fullscreen, on = function() mp.commandv("cycle", "fullscreen") end },
    } }
end

PAGES.recent = function()
    local O = require 'openers'
    local items = {}
    for _, p in ipairs(O.history) do
        items[#items + 1] = { label = O.is_url(p) and p or (O.basename(p):gsub("%.%w+$", "")), kind = "action",
            on = function() M.close(); O.open_paths({ p }, false) end }
    end
    return { title = "Recent files", items = items }
end

PAGES.open = function()
    local O = require 'openers'
    local function act(fn) return function() M.close(); fn() end end
    local items = {
        { label = "Open file...", kind = "action", on = act(function() O.pick_files(false) end) },
        { label = "Open folder...", kind = "action", on = act(function() O.pick_dir(false) end) },
        { label = "Open URL...", kind = "action", on = act(function() O.prompt(false) end) },
        { label = "Paste and play", kind = "action", on = act(function() O.paste(false) end) },
        { label = "Add file to playlist...", kind = "action", on = act(function() O.pick_files(true) end) },
        { label = "Add folder to playlist...", kind = "action", on = act(function() O.pick_dir(true) end) },
        { label = "Add URL to playlist...", kind = "action", on = act(function() O.prompt(true) end) },
    }
    if #O.history > 0 then items[#items + 1] = { label = "Recent files", kind = "submenu", page = "recent" } end
    return { title = "Open", items = items }
end

PAGES.root = function()
    local speed = mp.get_property_number("speed", 1)
    local items = {
        { label = "Playback speed", value = num_eq(speed, 1) and "Normal" or fmt_speed(speed), kind = "submenu", page = "speed" },
        { label = "Subtitles/CC", value = (S.sid and S.sub_visible) and selected_label("sub", S.sid) or "Off", kind = "submenu", page = "subs" },
        { label = "Audio", value = selected_label("audio", S.aid), kind = "submenu", page = "audio" },
        { label = "Video", value = S.vid and selected_label("video", S.vid) or "Auto", kind = "submenu", page = "video" },
        { label = "Aspect ratio", value = option_label(ASPECT, mp.get_property_number("video-aspect-override", -1)) or "Custom",
          kind = "submenu", page = "aspect" },
        { label = "Loop", value = ({ none = "None", file = "File", playlist = "Playlist" })[loop_state()], kind = "submenu", page = "loop" },
    }
    if #S.chapters > 0 then
        items[#items + 1] = { label = "Chapters", kind = "submenu", page = "chapters",
            value = string.format("%d/%d", math.max(S.chapter, 0) + 1, #S.chapters) }
    end
    return { title = "Settings", items = items }
end

------------------------------------------------------------------ control
local function top() return S.menu and S.menu.stack[#S.menu.stack] end

local function spec() return PAGES[top().id]() end

local function preselect(entry)
    entry.sel, entry.scroll = 1, 0
    local sp = PAGES[entry.id]()
    for i, it in ipairs(sp.items) do
        if it.kind == "radio" and it.checked then entry.sel = i; break end
    end
end

function M.is_open() return S.menu ~= nil end

function M.open(id)
    if TI.active() then TI.close() end
    require('panel').close()
    require('strip').close()
    local entry = { id = id or "root", sel = 1, scroll = 0 }
    preselect(entry)
    local was = S.menu ~= nil
    S.menu = { stack = { entry } }
    if not was then
        for _, k in ipairs(NAV) do
            mp.add_forced_key_binding(k, "ytosc-menu-" .. k, function() M.on_key(k) end, { repeatable = true })
        end
    end
    A.set(S.menu_a, 0)
    A.to(S.menu_a, 1, 0.12, mp.get_time())
    S.cb.show()
    S.cb.wake()
end

function M.close()
    if not S.menu then return end
    S.menu, S.menu_geo = nil, nil
    for _, k in ipairs(NAV) do mp.remove_key_binding("ytosc-menu-" .. k) end
    S.cb.wake()
end

function M.toggle()
    if S.menu then M.close() else M.open("root") end
end

local function push(id)
    local entry = { id = id }
    preselect(entry)
    table.insert(S.menu.stack, entry)
end

function M.back()
    if not S.menu then return end
    if #S.menu.stack > 1 then table.remove(S.menu.stack) else M.close() end
    S.cb.wake()
end

function M.set_sel(i)
    local t = top()
    if t and t.sel ~= i then t.sel = i; S.cb.wake() end
end

function M.move(d)
    local t = top()
    if not t then return end
    local n = #spec().items
    t.sel = U.clamp(t.sel + d, 1, math.max(n, 1))
    S.cb.wake()
end

function M.activate(i)
    if not S.menu then return end
    local it = spec().items[i]
    if not it then return end
    if it.kind == "submenu" then push(it.page)
    else
        it.on()
        if S.menu and not it.keep then M.back() end
    end
    S.cb.wake()
end

-- returns true when the key was consumed
function M.on_key(tok)
    if not S.menu then return false end
    local t = top()
    if tok == "j" or tok == "DOWN" then M.move(1)
    elseif tok == "k" or tok == "UP" then M.move(-1)
    elseif tok == "G" then M.move(1000)
    elseif tok == "g" then M.move(-1000)
    elseif tok == "l" or tok == "RIGHT" or tok == "ENTER" or tok == "KP_ENTER" or tok == "SPACE" then M.activate(t.sel)
    elseif tok == "h" or tok == "LEFT" or tok == "BS" then M.back()
    elseif tok == "ESC" or tok == "s" then M.close()
    else return false end
    return true
end

-- Builds popup geometry + hit regions; stored in S.menu_geo for the renderer.
function M.geometry(S_, C)
    local s = C.scale
    local t = top()
    local sp = spec()
    local items = sp.items
    local W = 300 * s
    local ih = 40 * s
    local header = (#S.menu.stack > 1) and ih or 0
    local maxh = math.min(S_.h * 0.7, S_.h - 150 * s)
    local H = math.min(header + #items * ih + 16 * s, maxh)
    local x2 = S_.w - 12 * s
    local y2 = S_.h - (4 + 48 + 22) * s
    local x1, y1 = x2 - W, y2 - H
    local nvis = math.max(1, math.floor((H - header - 16 * s) / ih))
    t.sel = U.clamp(t.sel, 1, math.max(#items, 1))
    if t.sel < t.scroll + 1 then t.scroll = t.sel - 1 end
    if t.sel > t.scroll + nvis then t.scroll = t.sel - nvis end
    t.scroll = U.clamp(t.scroll, 0, math.max(0, #items - nvis))

    local has_check = false
    for _, it in ipairs(items) do if it.kind == "radio" then has_check = true end end

    local g = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, ih = ih, header = header, title = sp.title,
        items = items, sel = t.sel, scroll = t.scroll, nvis = nvis, has_check = has_check }
    S_.menu_geo = g

    local regions = {}
    local ry0 = y1 + 8 * s + header
    for row = 1, nvis do
        local idx = t.scroll + row
        if idx > #items then break end
        local ry = ry0 + (row - 1) * ih
        regions[#regions + 1] = { id = "menu_item:" .. idx, x1 = x1, x2 = x2, y1 = ry, y2 = ry + ih }
    end
    if header > 0 then
        regions[#regions + 1] = { id = "menu_back", x1 = x1, x2 = x2, y1 = y1 + 8 * s, y2 = y1 + 8 * s + header }
    end
    regions[#regions + 1] = { id = "menu_bg", x1 = x1, x2 = x2, y1 = y1, y2 = y2 }
    return { regions = regions }
end

return M
