local U = require 'util'
local TB = require 'thumb'

local L = {}

function L.time_text(S)
    local dur, pos = S.dur or 0, S.pos or 0
    if S.scrub_frac and dur > 0 then pos = S.scrub_frac * dur end
    if dur <= 0 then return U.fmt_time(pos) end
    local a = S.remaining and ("-" .. U.fmt_time(dur - pos)) or U.fmt_time(pos)
    return a .. " / " .. U.fmt_time(dur)
end

function L.chapter_title(S)
    local dur = S.dur or 0
    if dur <= 0 then return nil end
    local t = S.scrub_frac and S.scrub_frac * dur or (S.pos or 0)
    local title
    for _, c in ipairs(S.chapters) do
        if c.time <= t + 0.001 then title = c.title else break end
    end
    if not title or title == "" then return nil end
    return title
end

-- Builds geometry + hit regions from window size and state.
-- Regions are tested in order, so earlier entries win on overlap.
-- `pre` carries regions (e.g. the settings popup) that must win over everything else.
function L.compute(S, C, pre)
    local s, w, h = C.scale, S.w, S.h
    local pad, bw, row_h = 12 * s, (C.touch_mode == "yes" and 56 or 48) * s, 48 * s
    local row_y1 = h - 4 * s - row_h
    local row_y2 = h - 4 * s
    local cy = (row_y1 + row_y2) / 2
    local bar_cy = row_y1 - 4 * s

    local lay = {
        s = s, pad = pad, cy = cy, row_y1 = row_y1, row_y2 = row_y2,
        icons = {}, regions = {},
        bar = { x1 = pad, x2 = w - pad, cy = bar_cy },
    }

    if pre then
        for _, r in ipairs(pre.regions) do lay.regions[#lay.regions + 1] = r end
    end

    local function region(id, x1, x2, y1, y2)
        lay.regions[#lay.regions + 1] = { id = id, x1 = x1, x2 = x2, y1 = y1 or row_y1, y2 = y2 or row_y2 }
    end

    if S.idle then
        local cx0, cy0 = w / 2, h / 2
        lay.idle = { x1 = cx0 - 80 * s, x2 = cx0 + 80 * s, y1 = cy0 + 34 * s, y2 = cy0 + 78 * s }
        region("idle_open", lay.idle.x1, lay.idle.x2, lay.idle.y1, lay.idle.y2)
    end

    if S.view == "mini" or w < 420 * s then
        -- compact layout: thin seekbar, play, expand and close
        lay.compact = true
        local bx, pb = 8 * s, 40 * s
        lay.bar = { x1 = bx, x2 = w - bx, cy = h - 10 * s }
        region("seekbar", bx, w - bx, h - 26 * s, h - 2 * s)
        region("play", bx, bx + pb, h - 70 * s, h - 30 * s)
        lay.icons.play = { cx = bx + pb / 2, cy = h - 50 * s }
        region("mini_close", w - 44 * s, w - 8 * s, 8 * s, 44 * s)
        lay.icons.close = { cx = w - 26 * s, cy = 26 * s }
        region("view_expand", w - 84 * s, w - 48 * s, 8 * s, 44 * s)
        lay.icons.expand = { cx = w - 66 * s, cy = 26 * s }
        return lay
    end

    region("seekbar", pad, w - pad, bar_cy - (C.touch_mode == "yes" and 16 or 12) * s, bar_cy + 10 * s)

    lay.top = { h = 56 * s }
    local show_wc = C.window_controls == "yes" or (C.window_controls == "auto" and S.border == false and not S.fullscreen)
    if show_wc then
        local wcw, wch = 46 * s, 40 * s
        lay.wc = { x1 = w - 3 * wcw, w = wcw, h = wch }
        region("wc_close", w - wcw, w, 0, wch)
        region("wc_max", w - 2 * wcw, w - wcw, 0, wch)
        region("wc_min", w - 3 * wcw, w - 2 * wcw, 0, wch)
    end

    -- right group (right to left): fullscreen, settings, cc
    local x2 = w - pad
    region("fullscreen", x2 - bw, x2)
    lay.icons.fullscreen = { cx = x2 - bw / 2, cy = cy }
    x2 = x2 - bw
    region("settings", x2 - bw, x2)
    lay.icons.settings = { cx = x2 - bw / 2, cy = cy }
    x2 = x2 - bw
    region("cc", x2 - bw, x2)
    lay.icons.cc = { cx = x2 - bw / 2, cy = cy }
    x2 = x2 - bw
    region("view", x2 - bw, x2)
    lay.icons.view = { cx = x2 - bw / 2, cy = cy }
    x2 = x2 - bw
    region("playlist", x2 - bw, x2)
    lay.icons.playlist = { cx = x2 - bw / 2, cy = cy }
    x2 = x2 - bw
    region("open", x2 - bw, x2)
    lay.icons.open = { cx = x2 - bw / 2, cy = cy }
    local right_edge = x2 - bw
    local limit = right_edge
    if w > 1000 * s then
        lay.strip_toggle = { cx = w / 2, cy = cy }
        region("strip_toggle", w / 2 - 80 * s, w / 2 + 80 * s)
        limit = math.min(limit, w / 2 - 90 * s)
    end

    -- left group
    local x = pad
    region("play", x, x + bw)
    lay.icons.play = { cx = x + bw / 2, cy = cy }
    x = x + bw

    if S.has_next then
        region("next", x, x + bw)
        lay.icons.next = { cx = x + bw / 2, cy = cy }
        x = x + bw
    end

    region("volume_icon", x, x + bw)
    lay.icons.volume = { cx = x + bw / 2, cy = cy }
    x = x + bw

    local vw = S.vol_w.v
    if vw > 2 * s then
        region("volume_slider", x, x + vw)
        lay.vol = { x1 = x + 6 * s, x2 = x + vw - 6 * s, cy = cy }
        x = x + vw
    end

    x = x + 6 * s
    local fs = 14 * s
    local text = L.time_text(S)
    local tw = U.text_w(text, fs)
    lay.time = { text = text, x = x, fs = fs }
    region("time", x, x + tw)

    local cx0 = x + tw + 10 * s
    local ct = L.chapter_title(S)
    if ct then
        local maxw = limit - cx0 - 12 * s
        if maxw > 40 * s then
            local label = U.ellipsize("\226\128\162 " .. ct, maxw, fs)
            lay.chapter = { x = cx0, text = label }
            region("chapter", cx0, cx0 + U.text_w(label, fs))
        end
    end

    -- thumbfast preview above the hover bubble
    local dur = S.dur or 0
    if dur > 0 and (S.hover == "seekbar" or S.drag == "seek") and TB.available() then
        local tw, th = TB.size()
        local mx = U.clamp(S.mouse.x, lay.bar.x1, lay.bar.x2)
        local t = U.clamp((mx - lay.bar.x1) / (lay.bar.x2 - lay.bar.x1), 0, 1) * dur
        local has_title = false
        for _, c in ipairs(S.chapters) do
            if c.time <= t + 0.001 and c.title and c.title ~= "" then has_title = true elseif c.time > t then break end
        end
        local bubble = (has_title and 40 or 24) * s
        lay.thumb = { x = U.clamp(mx - tw / 2, lay.bar.x1, math.max(lay.bar.x1, lay.bar.x2 - tw)),
            y = bar_cy - 16 * s - bubble - 6 * s - th, w = tw, h = th, t = t }
    end

    return lay
end

-- Computes popup geometry (when the menu is open) and the full layout.
function L.build(S, C)
    local pre
    if S.menu then pre = require('menus').geometry(S, C) else S.menu_geo = nil end
    if S.panel then pre = require('panel').geometry(S, C) else S.panel_geo = nil end
    if S.strip then pre = require('strip').geometry(S, C) else S.strip_geo = nil end
    return L.compute(S, C, pre)
end

function L.hit(lay, x, y)
    for _, r in ipairs(lay.regions) do
        if x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2 then return r.id end
    end
    return nil
end

return L
