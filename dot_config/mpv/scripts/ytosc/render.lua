local D = require 'draw'
local I = require 'icons'
local U = require 'util'

local R = {}

local function draw_menu(ev, S, C, T)
    local g = S.menu_geo
    if not g then return end
    local function add(x) ev[#ev + 1] = x end
    local function col(k) return T.ass(k) end
    local s, a, font = C.scale, S.menu_a.v, C.font
    local on, onv = col("on_surface"), col("on_surface_variant")
    add(D.shape(D.rrect(g.x1, g.y1, g.x2, g.y2, 12 * s), col("surface"), C.panel_alpha * a))
    local y = g.y1 + 8 * s
    local fs = 15 * s
    if g.header > 0 then
        local cy = y + g.ih / 2
        I.chevron(ev, g.x1 + 26 * s, cy, 18 * s, on, a, "left")
        add(D.text(U.ellipsize(g.title, g.x2 - g.x1 - 70 * s, fs), g.x1 + 50 * s, cy, 4, fs, on, a, font, "\\b1"))
        add(D.shape(D.rect(g.x1 + 8 * s, y + g.ih - 1, g.x2 - 8 * s, y + g.ih), on, 0.12 * a))
        y = y + g.ih
    end
    for row = 1, g.nvis do
        local idx = g.scroll + row
        local it = g.items[idx]
        if not it then break end
        local ry = y + (row - 1) * g.ih
        local cy = ry + g.ih / 2
        if idx == g.sel then
            add(D.shape(D.rrect(g.x1 + 8 * s, ry, g.x2 - 8 * s, ry + g.ih, 8 * s), col("surface_container"), 0.9 * a))
        end
        local lx = g.x1 + (g.has_check and 52 * s or 22 * s)
        if it.kind == "radio" and it.checked then I.check(ev, g.x1 + 30 * s, cy, 18 * s, on, a) end
        local rx = g.x2 - 22 * s
        if it.kind == "submenu" then
            I.chevron(ev, g.x2 - 30 * s, cy, 18 * s, onv, a, "right")
            rx = g.x2 - 46 * s
        end
        local value = it.value
        if it.kind == "toggle" then value = it.checked and "On" or "Off" end
        local vw = value and (U.text_w(value, 14 * s) + 12 * s) or 0
        add(D.text(U.ellipsize(it.label, g.x2 - lx - vw - 22 * s, fs), lx, cy, 4, fs, on, a, font))
        if value then add(D.text(U.ellipsize(value, 150 * s, 14 * s), rx, cy, 6, 14 * s, onv, a, font)) end
    end
end

local function draw_panel(ev, S, C, T)
    local g = S.panel_geo
    if not g then return end
    local function add(x) ev[#ev + 1] = x end
    local function col(k) return T.ass(k) end
    local s, a, font = C.scale, S.panel_a.v, C.font
    local on, onv = col("on_surface"), col("on_surface_variant")
    add(D.shape(D.rrect(g.x1, g.y1, g.x2, g.y2, 12 * s), col("surface"), C.panel_alpha * a))
    add(D.text("Playlist", g.x1 + 20 * s, g.y1 + 28 * s, 4, 17 * s, on, a, font, "\\b1"))
    add(D.text("\195\151", g.x2 - 28 * s, g.y1 + 27 * s, 5, 24 * s, onv, a, font))
    local sub
    if S.panel.filter ~= "" then
        sub = string.format("/%s  \194\183  %d of %d", S.panel.filter, #g.list, g.total)
    else
        sub = string.format("%d item%s", g.total, g.total == 1 and "" or "s")
    end
    add(D.text(U.ellipsize(sub, g.x2 - g.x1 - 40 * s, 13 * s), g.x1 + 20 * s, g.y1 + 50 * s, 4, 13 * s, onv, a, font))
    for _, pl in ipairs(g.pills) do
        add(D.shape(D.rrect(pl.x1, g.py1, pl.x2, g.py2, 16 * s), pl.active and col("primary") or col("surface_container"), 0.95 * a))
        add(D.text(pl.label, (pl.x1 + pl.x2) / 2, (g.py1 + g.py2) / 2, 5, 13 * s,
            pl.active and col("on_primary") or on, a, font))
    end
    if #g.list == 0 then
        add(D.text(g.total == 0 and "Playlist is empty" or "No matches", (g.x1 + g.x2) / 2, g.y1 + g.header + 40 * s, 5, 14 * s, onv, a, font))
    end
    for row = 1, g.nvis do
        local idx = g.scroll + row
        local e = g.list[idx]
        if not e then break end
        local ry = g.y1 + g.header + (row - 1) * g.ih
        local cy = ry + g.ih / 2
        if idx == g.sel then
            add(D.shape(D.rrect(g.x1 + 8 * s, ry, g.x2 - 8 * s, ry + g.ih, 8 * s), col("surface_container"), 0.9 * a))
        end
        if e.current then
            I.play(ev, g.x1 + 30 * s, cy, 16 * s, col("primary"), a)
        else
            add(D.text(tostring(e.idx), g.x1 + 30 * s, cy, 5, 13 * s, onv, a, font))
        end
        add(D.text(U.ellipsize(e.title, g.x2 - g.x1 - 80 * s, 15 * s), g.x1 + 54 * s, cy, 4, 15 * s, on, a, font,
            e.current and "\\b1" or nil))
    end
end

local function draw_strip(ev, S, C, T)
    local g = S.strip_geo
    if not g then return end
    local function add(x) ev[#ev + 1] = x end
    local function col(k) return T.ass(k) end
    local s, font = C.scale, C.font
    local on, onv = col("on_surface"), col("on_surface_variant")
    for k = 1, g.nvis do
        local idx = g.scroll + k
        local it = g.items[idx]
        if not it then break end
        local x, y = g.x0 + (k - 1) * (g.cw + g.gap), g.cy
        if not (it.thumb and it.thumb.state == "ready") then
            add(D.shape(D.rect(x, y, x + g.cw, y + g.th), col("surface"), 0.9))
            I.play(ev, x + g.cw / 2, y + g.th / 2, 28 * s, onv, 0.5)
        end
        add(D.shape(D.rect(x, y + g.th, x + g.cw, y + g.ch), col("surface"), 0.95))
        add(D.text(U.ellipsize(it.title, g.cw - 20 * s, 13 * s), x + 10 * s, y + g.th + 14 * s, 4, 13 * s, on, 1, font))
        add(D.text(it.label, x + 10 * s, y + g.th + 30 * s, 4, 11 * s, onv, 1, font))
        if idx == g.sel then
            add(D.shape(D.rrect(x - 3 * s, y - 3 * s, x + g.cw + 3 * s, y + g.ch + 3 * s, 5 * s)
                .. " " .. D.rrect_ccw(x, y, x + g.cw, y + g.ch, 2 * s), col("primary"), 1))
        end
    end
    local mid = g.cy + g.th / 2
    if g.can_prev then
        add(D.shape(D.circle(g.pad + 20 * s, mid, 18 * s), col("surface"), 0.92))
        I.chevron(ev, g.pad + 20 * s, mid, 20 * s, on, 1, "left")
    end
    if g.can_next then
        add(D.shape(D.circle(S.w - g.pad - 20 * s, mid, 18 * s), col("surface"), 0.92))
        I.chevron(ev, S.w - g.pad - 20 * s, mid, 20 * s, on, 1, "right")
    end
end

local function draw_idle(ev, S, C, T, lay)
    if not lay.idle then return end
    local function add(x) ev[#ev + 1] = x end
    local function col(k) return T.ass(k) end
    local s, font = C.scale, C.font
    local cx, cy = S.w / 2, S.h / 2
    local i = lay.idle
    add(D.text("Nothing playing", cx, cy - 34 * s, 5, 28 * s, col("on_surface"), 1, font, "\\b1"))
    add(D.text("Open a file, folder or URL", cx, cy - 2 * s, 5, 15 * s, col("on_surface_variant"), 1, font))
    local hover = S.hover == "idle_open"
    add(D.shape(D.rrect(i.x1, i.y1, i.x2, i.y2, 22 * s), col("primary"), hover and 1 or 0.9))
    add(D.text("Open...", cx, (i.y1 + i.y2) / 2, 5, 16 * s, col("on_primary"), 1, font, "\\b1"))
    add(D.text("o  open    O  folder    p  paste URL", cx, i.y2 + 28 * s, 5, 13 * s, col("on_surface_variant"), 1, font))
end

local function draw_ripple(ev, S, C, T, now)
    local r = S.ripple
    if not r then return end
    local p = (now - r.t0) / 0.5
    if p >= 1 then return end
    local e = U.ease(p)
    ev[#ev + 1] = D.shape(D.circle(r.x, r.y, (30 + 110 * e) * C.scale), T.ass("on_surface"), 0.28 * (1 - p))
end

local function draw_topbar(ev, S, C, T, lay, vis)
    local s, font = C.scale, C.font
    local function add(x) ev[#ev + 1] = x end
    local function col(k) return T.ass(k) end
    local on, onv = col("on_surface"), col("on_surface_variant")
    local sh, N = 96 * s, 32
    for i = 0, N - 1 do
        local op = C.scrim_alpha * 0.8 * ((N - i) / N) ^ 2 * vis
        add(D.shape(D.rect(0, i * sh / N, S.w, i * sh / N + sh / N + 1), col("scrim"), op))
    end
    local right = S.w - lay.pad
    if lay.wc then
        right = lay.wc.x1 - 8 * s
        local ids, icons = { "wc_min", "wc_max", "wc_close" }, { I.minimize, I.maximize, I.close }
        for i, id in ipairs(ids) do
            local x1 = lay.wc.x1 + (i - 1) * lay.wc.w
            if S.hover == id then
                add(D.shape(D.rect(x1, 0, x1 + lay.wc.w, lay.wc.h),
                    id == "wc_close" and col("error") or col("surface_container"), 0.9 * vis))
            end
            icons[i](ev, x1 + lay.wc.w / 2, lay.wc.h / 2, 22 * s, on, vis)
        end
    end
    if S.pl_count > 1 and S.pl_pos >= 0 then
        local pos = string.format("%d/%d", S.pl_pos + 1, S.pl_count)
        add(D.text(pos, right, 24 * s, 6, 14 * s, onv, vis, font))
        right = right - U.text_w(pos, 14 * s) - 16 * s
    end
    if S.title ~= "" then
        add(D.text(U.ellipsize(S.title, right - lay.pad, 17 * s), lay.pad, 24 * s, 4, 17 * s, on, vis, font, "\\b1"))
    end
end

local function draw_compact(ev, S, C, T, lay, vis)
    local s = C.scale
    local on = T.ass("on_surface")
    local ic = lay.icons
    if S.paused then I.play(ev, ic.play.cx, ic.play.cy, 24 * s, on, vis)
    else I.pause(ev, ic.play.cx, ic.play.cy, 24 * s, on, vis) end
    I.fullscreen(ev, ic.expand.cx, ic.expand.cy, 22 * s, on, vis, false)
    I.close(ev, ic.close.cx, ic.close.cy, 22 * s, on, vis)
end

local function draw_input(ev, S, C, T, lay, now)
    local inp = S.input
    if not inp then return end
    local function col(k) return T.ass(k) end
    local s, font = C.scale, C.font
    local bw, bh = 420 * s, 48 * s
    local cx, cy = S.w / 2, lay.bar.cy - 64 * s
    local x1 = cx - bw / 2
    ev[#ev + 1] = D.shape(D.rrect(x1, cy - bh / 2, x1 + bw, cy + bh / 2, 10 * s), col("surface"), 0.96)
    local fs = 16 * s
    local tx = x1 + 16 * s
    if inp.prompt ~= "" then
        ev[#ev + 1] = D.text(inp.prompt, tx, cy, 4, 14 * s, col("on_surface_variant"), 1, font)
        tx = tx + U.text_w(inp.prompt, 14 * s) + 14 * s
    end
    ev[#ev + 1] = D.text(U.ellipsize(inp.text, x1 + bw - tx - 16 * s, fs), tx, cy, 4, fs, col("on_surface"), 1, font)
    if now % 1 < 0.6 then
        local cxp = tx + U.text_w(inp.text:sub(1, inp.caret), fs)
        ev[#ev + 1] = D.shape(D.rect(cxp, cy - 11 * s, cxp + 1.5 * s, cy + 11 * s), col("primary"), 1)
    end
end

local function chapter_at(S, t)
    local title
    for _, c in ipairs(S.chapters) do
        if c.time <= t + 0.001 then title = c.title else break end
    end
    if title == "" then return nil end
    return title
end

-- Returns the full ASS overlay text, or "" when there is nothing to draw.
function R.build(S, C, T, now)
    local ev = {}
    local function add(x) ev[#ev + 1] = x end
    local lay = S.layout
    local s, w, h = lay.s, S.w, S.h
    local vis = S.vis.v
    local font = C.font
    local function col(k) return T.ass(k) end

    -- thin progress line that remains while the controls are hidden
    if C.progress_line and not S.idle and (S.dur or 0) > 0 and vis < 0.99 then
        local a = 1 - vis
        local ph = (lay.compact and 2 or 3) * s
        local frac = U.clamp((S.pos or 0) / S.dur, 0, 1)
        add(D.shape(D.rect(0, h - ph, w, h), col("surface_variant"), 0.55 * a))
        add(D.shape(D.rect(0, h - ph, w * frac, h), col("primary"), a))
    end

    if vis > 0.01 then
        ---------------------------------------------------------------- scrim
        local sh, N = (lay.compact and 100 or 170) * s, 48
        local y0 = h - sh
        for i = 0, N - 1 do
            local y1 = y0 + i * sh / N
            local op = C.scrim_alpha * ((i + 1) / N) ^ 2 * vis
            add(D.shape(D.rect(0, y1, w, y1 + sh / N + 1), col("scrim"), op))
        end

        -------------------------------------------------------------- seekbar
        local bar = lay.bar
        local bx1, bx2, bcy = bar.x1, bar.x2, bar.cy
        local dur = S.dur or 0
        local d_eff = dur > 0 and dur or 1
        local bh = S.bar_h.v
        local frac = 0
        if dur > 0 then frac = S.scrub_frac or U.clamp((S.pos or 0) / dur, 0, 1) end
        local played_x = bx1 + (bx2 - bx1) * frac
        local function px(t) return bx1 + (bx2 - bx1) * U.clamp(t / d_eff, 0, 1) end

        local bounds = { 0 }
        if dur > 0 then
            for _, c in ipairs(S.chapters) do
                if c.time > 0.5 and c.time < dur - 0.5 then bounds[#bounds + 1] = c.time end
            end
        end
        bounds[#bounds + 1] = d_eff
        local gap = (#bounds > 2) and 2 * s or 0
        local y1, y2, r = bcy - bh / 2, bcy + bh / 2, bh / 2

        for i = 1, #bounds - 1 do
            local sx1 = px(bounds[i]) + (i > 1 and gap / 2 or 0)
            local sx2 = px(bounds[i + 1]) - (i < #bounds - 1 and gap / 2 or 0)
            if sx2 > sx1 then
                add(D.shape(D.rrect(sx1, y1, sx2, y2, r), col("surface_variant"), 0.85 * vis))
                for _, rg in ipairs(S.cache) do
                    local a, b = math.max(sx1, px(rg.s)), math.min(sx2, px(rg.e))
                    if b > a then add(D.shape(D.rrect(a, y1, b, y2, r), col("outline"), 0.8 * vis)) end
                end
                local pe = math.min(sx2, played_x)
                if pe > sx1 then add(D.shape(D.rrect(sx1, y1, pe, y2, r), col("primary"), vis)) end
            end
        end
        if S.dot_r.v > 0.5 and dur > 0 then
            add(D.shape(D.circle(played_x, bcy, S.dot_r.v), col("primary"), vis))
        end

        -- hover / scrub bubble
        if dur > 0 and (S.hover == "seekbar" or S.drag == "seek") then
            local mx = U.clamp(S.mouse.x, bx1, bx2)
            local t = U.clamp((mx - bx1) / (bx2 - bx1), 0, 1) * dur
            local label = U.fmt_time(t)
            local title = chapter_at(S, t)
            local fs = 13 * s
            local bw_ = math.max(U.text_w(label, fs), title and U.text_w(title, fs - 1) or 0) + 18 * s
            local bhh = title and 40 * s or 24 * s
            local bxc = U.clamp(mx, bx1 + bw_ / 2, bx2 - bw_ / 2)
            local by2 = bcy - 16 * s
            local by1 = by2 - bhh
            add(D.shape(D.rrect(bxc - bw_ / 2, by1, bxc + bw_ / 2, by2, 6 * s), col("surface"), C.panel_alpha * vis))
            if title then
                add(D.text(title, bxc, by1 + bhh * 0.30, 5, fs - 1, col("on_surface_variant"), vis, font))
                add(D.text(label, bxc, by1 + bhh * 0.70, 5, fs, col("on_surface"), vis, font))
            else
                add(D.text(label, bxc, by1 + bhh / 2, 5, fs, col("on_surface"), vis, font))
            end
        end

        ------------------------------------------------------------- controls
        if lay.compact then
            draw_compact(ev, S, C, T, lay, vis)
        else
        draw_topbar(ev, S, C, T, lay, vis)
        local ic, isz, on = lay.icons, 24 * s, col("on_surface")
        if S.paused then I.play(ev, ic.play.cx, ic.play.cy, isz, on, vis)
        else I.pause(ev, ic.play.cx, ic.play.cy, isz, on, vis) end
        if ic.next then I.next(ev, ic.next.cx, ic.next.cy, isz, on, vis) end
        local level = S.volume_max > 0 and (S.volume / S.volume_max) or 0
        I.volume(ev, ic.volume.cx, ic.volume.cy, isz, on, vis, level, S.mute or S.volume <= 0)

        if lay.vol then
            local e = U.clamp(S.vol_w.v / (64 * s), 0, 1)
            local v = lay.vol
            local fx = v.x1 + (v.x2 - v.x1) * (S.mute and 0 or U.clamp(level, 0, 1))
            add(D.shape(D.rrect(v.x1, v.cy - 1.5 * s, v.x2, v.cy + 1.5 * s, 1.5 * s), on, 0.3 * e * vis))
            add(D.shape(D.rrect(v.x1, v.cy - 1.5 * s, fx, v.cy + 1.5 * s, 1.5 * s), on, e * vis))
            add(D.shape(D.circle(fx, v.cy, 6 * s), on, e * vis))
        end

        add(D.text(lay.time.text, lay.time.x, lay.cy, 4, lay.time.fs, on, vis, font))
        if lay.chapter then
            add(D.text(lay.chapter.text, lay.chapter.x, lay.cy, 4, lay.time.fs, col("on_surface_variant"), vis, font))
        end

        I.folder(ev, ic.open.cx, ic.open.cy, isz, on, vis)
        I.list(ev, ic.playlist.cx, ic.playlist.cy, isz, on, vis)
        if lay.strip_toggle then
            local sx = lay.strip_toggle.cx
            I.chevron(ev, sx - 52 * s, lay.cy, 18 * s, on, vis, S.strip and "down" or "up")
            add(D.text("More videos", sx - 36 * s, lay.cy, 4, 13 * s, on, vis, font))
        end
        I.view(ev, ic.view.cx, ic.view.cy, isz, on, vis)
        I.cc(ev, ic.cc.cx, ic.cc.cy, isz, on, vis * (S.sub_count > 0 and 1 or 0.4), font, S.sub_on, col("primary"))
        I.gear(ev, ic.settings.cx, ic.settings.cy, isz, on, vis, S.menu and 45 * S.menu_a.v or 0)
        I.fullscreen(ev, ic.fullscreen.cx, ic.fullscreen.cy, isz, on, vis, S.fullscreen)

        end -- not compact

        if C.debug then
            for _, rg in ipairs(lay.regions) do
                add(D.shape(D.rect(rg.x1, rg.y1, rg.x2, rg.y2), "&H0000FF&", 0.15))
            end
        end
    end

    draw_ripple(ev, S, C, T, now)
    draw_panel(ev, S, C, T)
    draw_strip(ev, S, C, T)
    draw_menu(ev, S, C, T)
    draw_input(ev, S, C, T, lay, now)
    if S.idle then draw_idle(ev, S, C, T, lay) end

    ------------------------------------------------- pending keys indicator
    if S.pending ~= "" then
        local fs = 14 * s
        local pw = U.text_w(S.pending, fs) + 20 * s
        local py = lay.bar.cy - 34 * s
        add(D.shape(D.rrect(lay.pad, py - 12 * s, lay.pad + pw, py + 12 * s, 6 * s), col("surface"), 0.92))
        add(D.text(S.pending, lay.pad + 10 * s, py, 4, fs, col("on_surface"), 1, font))
    end

    ------------------------------------------------------------------ toast
    if S.toast then
        local left = S.toast.t_end - now
        if left > 0 then
            local a = U.clamp(left / 0.3, 0, 1)
            local fs = 16 * s
            local tw = U.text_w(S.toast.text, fs) + 28 * s
            local tx, ty = w / 2, h * 0.12
            if S.toast.pos == "left" then tx, ty = w * 0.22, h * 0.45
            elseif S.toast.pos == "right" then tx, ty = w * 0.78, h * 0.45 end
            add(D.shape(D.rrect(tx - tw / 2, ty - 17 * s, tx + tw / 2, ty + 17 * s, 17 * s), col("surface"), 0.92 * a))
            add(D.text(S.toast.text, tx, ty, 5, fs, col("on_surface"), a, font))
        end
    end

    return table.concat(ev, "\n")
end

return R
