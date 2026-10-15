-- "More videos" strip: a row of cards above the seekbar (playlist, folder siblings, recent files)
-- with ffmpeg-generated thumbnails drawn through mpv's overlay-add.
local utils = require 'mp.utils'
local U = require 'util'
local S = require 'state'
local C = require 'config'
local O = require 'openers'

local T = {}
local KEYS = { "h", "l", "LEFT", "RIGHT", "ENTER", "KP_ENTER", "SPACE", "g", "G", "ESC", "v" }
local MAX_ITEMS = 30

--------------------------------------------------------------- thumbnails
local TH = { queue = {}, running = 0, dir = nil, dir_ready = false, placed = {} }

local function hash(str)
    local h = 5381
    for i = 1, #str do h = (h * 33 + str:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

local function cache_dir()
    if not TH.dir then TH.dir = mp.command_native({ "expand-path", "~~cache/ytosc/thumbs" }) end
    if not TH.dir_ready then
        mp.command_native({ name = "subprocess", args = { "mkdir", "-p", TH.dir }, playback_only = false })
        TH.dir_ready = true
    end
    return TH.dir
end

local function file_size(p)
    local i = utils.file_info(p)
    return i and i.is_file and i.size or 0
end

local function pump(tw, th)
    while TH.running < 2 and #TH.queue > 0 do
        local job = table.remove(TH.queue, 1)
        TH.running = TH.running + 1
        local args = { "ffmpeg", "-v", "error", "-y" }
        if job.try == 1 then args[#args + 1] = "-ss"; args[#args + 1] = "3" end
        for _, a in ipairs({ "-i", job.item.path, "-frames:v", "1", "-vf",
            string.format("scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2:color=black", tw, th, tw, th),
            "-pix_fmt", "bgra", "-f", "rawvideo", job.file }) do
            args[#args + 1] = a
        end
        mp.command_native_async({ name = "subprocess", args = args, playback_only = false }, function()
            TH.running = TH.running - 1
            if file_size(job.file) == tw * th * 4 then
                job.item.thumb.state = "ready"
            elseif job.try == 1 then
                job.try = 2
                table.insert(TH.queue, 1, job)
            else
                job.item.thumb.state = "failed"
            end
            S.cb.wake()
            pump(tw, th)
        end)
    end
end

local function request(item, tw, th)
    if item.thumb or O.is_url(item.path) then return end
    if not C.strip_thumbnails then item.thumb = { state = "failed" }; return end
    local info = utils.file_info(item.path)
    if not info or not info.is_file then item.thumb = { state = "failed" }; return end
    local file = utils.join_path(cache_dir(), hash(item.path .. info.mtime .. info.size .. tw .. "x" .. th) .. ".bgra")
    if file_size(file) == tw * th * 4 then item.thumb = { state = "ready", file = file }; return end
    if not O.which("ffmpeg") then item.thumb = { state = "failed" }; return end
    item.thumb = { state = "pending", file = file }
    TH.queue[#TH.queue + 1] = { item = item, file = file, try = 1 }
    pump(tw, th)
end

-- keep mpv overlays in sync with the visible cards
local function sync(geo)
    local want = {}
    if geo then
        for k = 1, geo.nvis do
            local item = geo.items[geo.scroll + k]
            if item and item.thumb and item.thumb.state == "ready" then
                local x = math.floor(geo.x0 + (k - 1) * (geo.cw + geo.gap) + 0.5)
                local y = math.floor(geo.cy + 0.5)
                local key = item.thumb.file .. ":" .. x .. ":" .. y
                want[k - 1] = key
                if TH.placed[k - 1] ~= key then
                    mp.commandv("overlay-add", tostring(k - 1), tostring(x), tostring(y), item.thumb.file, "0", "bgra",
                        tostring(geo.tw), tostring(geo.th), tostring(geo.tw * 4))
                    TH.placed[k - 1] = key
                end
            end
        end
    end
    for id in pairs(TH.placed) do
        if not want[id] then
            mp.commandv("overlay-remove", tostring(id))
            TH.placed[id] = nil
        end
    end
end

------------------------------------------------------------------- items
local function strip_ext(n) return (n:gsub("%.%w+$", "")) end

function T.build()
    local items, seen = {}, {}
    local cur_path = O.abs(mp.get_property("path") or "")
    seen[cur_path] = true
    local function add(it)
        if #items < MAX_ITEMS and not seen[it.path] then
            seen[it.path] = true
            items[#items + 1] = it
        end
    end
    for src in C.strip_sources:gmatch("[^,%s]+") do
        if src == "playlist" then
            local n, cur = #S.playlist, 0
            for i, e in ipairs(S.playlist) do if e.current then cur = i end end
            for off = 1, n - 1 do
                local i = ((cur - 1 + off) % n) + 1
                local e = S.playlist[i]
                local path = O.abs(e.filename or "")
                local title = (e.title and e.title ~= "") and e.title or strip_ext(O.basename(path))
                add({ title = title, path = path, pl_index = i - 1, label = "In playlist" })
            end
        elseif src == "dir" and #S.playlist <= 1 and cur_path ~= "" and not O.is_url(cur_path) then
            local sib = O.sorted_media(O.dir_of(cur_path), false)
            local cur_i = 0
            for i, p in ipairs(sib) do if O.basename(p) == O.basename(cur_path) then cur_i = i end end
            for off = 1, #sib do
                local p = sib[((cur_i - 1 + off) % #sib) + 1]
                add({ title = strip_ext(O.basename(p)), path = p, label = "In folder" })
            end
        elseif src == "recent" then
            for _, p in ipairs(O.history) do
                add({ title = O.is_url(p) and p or strip_ext(O.basename(p)), path = p, label = "Recent" })
            end
        end
    end
    return items
end

------------------------------------------------------------------ control
function T.is_open() return S.strip ~= nil end

function T.open()
    require('menus').close()
    require('panel').close()
    if S.strip then return end
    S.strip = { items = T.build(), sel = 1, scroll = 0, ensure = true }
    for _, k in ipairs(KEYS) do
        mp.add_forced_key_binding(k, "ytosc-st-" .. k, function() T.on_key(k) end, { repeatable = true })
    end
    S.cb.show()
    S.cb.wake()
end

function T.close()
    if not S.strip then return end
    for _, k in ipairs(KEYS) do mp.remove_key_binding("ytosc-st-" .. k) end
    S.strip, S.strip_geo = nil, nil
    sync(nil)
    S.cb.wake()
end

function T.toggle()
    if S.strip then T.close() else T.open() end
end

function T.set_sel(i)
    if S.strip and S.strip.sel ~= i then S.strip.sel = i; S.cb.wake() end
end

function T.scroll(d)
    if not S.strip then return end
    S.strip.scroll = S.strip.scroll + d
    S.cb.wake()
end

function T.activate(i)
    local it = S.strip and S.strip.items[i]
    if not it then return end
    T.close()
    if it.pl_index then mp.commandv("playlist-play-index", tostring(it.pl_index))
    else O.open_paths({ it.path }, false) end
end

function T.on_key(tok)
    local st = S.strip
    if not st then return end
    local n = #st.items
    if tok == "l" or tok == "RIGHT" then st.sel = U.clamp(st.sel + 1, 1, math.max(n, 1)); st.ensure = true
    elseif tok == "h" or tok == "LEFT" then st.sel = U.clamp(st.sel - 1, 1, math.max(n, 1)); st.ensure = true
    elseif tok == "G" then st.sel = math.max(n, 1); st.ensure = true
    elseif tok == "g" then st.sel = 1; st.ensure = true
    elseif tok == "ENTER" or tok == "KP_ENTER" or tok == "SPACE" then T.activate(st.sel); return
    elseif tok == "ESC" or tok == "v" then T.close(); return end
    S.cb.wake()
end

function T.geometry(S_, C_)
    local s, st = C_.scale, S.strip
    local pad, gap = 12 * s, 12 * s
    local cw, tw_, th_, tt = 200 * s, math.floor(200 * s), math.floor(112 * s), 40 * s
    local ch = th_ + tt
    local bar_cy = S_.h - 4 * s - 48 * s - 4 * s
    local cy = bar_cy - 18 * s - ch
    local x0 = pad + 44 * s
    local avail = S_.w - 2 * pad - 88 * s
    local nvis = math.max(1, math.floor((avail + gap) / (cw + gap)))
    local n = #st.items
    st.sel = U.clamp(st.sel, 1, math.max(n, 1))
    if st.ensure then
        if st.sel < st.scroll + 1 then st.scroll = st.sel - 1
        elseif st.sel > st.scroll + nvis then st.scroll = st.sel - nvis end
        st.ensure = false
    end
    st.scroll = U.clamp(st.scroll, 0, math.max(0, n - nvis))

    local geo = { items = st.items, nvis = nvis, scroll = st.scroll, sel = st.sel, cw = cw, ch = ch,
        tw = tw_, th = th_, tt = tt, gap = gap, x0 = x0, cy = cy, pad = pad, bar_cy = bar_cy,
        can_prev = st.scroll > 0, can_next = st.scroll + nvis < n }
    S_.strip_geo = geo

    local regions = {}
    for k = 1, nvis do
        local idx = st.scroll + k
        local it = st.items[idx]
        if not it then break end
        local x = x0 + (k - 1) * (cw + gap)
        regions[#regions + 1] = { id = "strip_card:" .. idx, x1 = x, x2 = x + cw, y1 = cy, y2 = cy + ch }
        request(it, tw_, th_)
    end
    if geo.can_prev then regions[#regions + 1] = { id = "strip_prev", x1 = pad, x2 = pad + 40 * s, y1 = cy, y2 = cy + ch } end
    if geo.can_next then regions[#regions + 1] = { id = "strip_next", x1 = S_.w - pad - 40 * s, x2 = S_.w - pad, y1 = cy, y2 = cy + ch } end
    regions[#regions + 1] = { id = "strip_bg", x1 = pad, x2 = S_.w - pad, y1 = cy - 12 * s, y2 = cy + ch + 8 * s }
    sync(geo)
    return { regions = regions }
end

-- exposed for tests
T._hash, T._sync = hash, sync

return T
