-- tiny ASS drawing helpers (no dependency on mp.assdraw)
local D = {}
local fmt = string.format

local function pt(x, y) return fmt("%.1f %.1f", x, y) end

function D.ahex(op)
    if op < 0 then op = 0 elseif op > 1 then op = 1 end
    return fmt("%02X", math.floor((1 - op) * 255 + 0.5))
end

function D.rect(x1, y1, x2, y2)
    return "m " .. pt(x1, y1) .. " l " .. pt(x2, y1) .. " " .. pt(x2, y2) .. " " .. pt(x1, y2)
end

function D.rrect(x1, y1, x2, y2, r)
    r = math.min(r, (x2 - x1) / 2, (y2 - y1) / 2)
    if r < 0.5 then return D.rect(x1, y1, x2, y2) end
    local k = 0.5523 * r
    return table.concat({
        "m " .. pt(x1 + r, y1),
        "l " .. pt(x2 - r, y1),
        "b " .. pt(x2 - r + k, y1) .. " " .. pt(x2, y1 + r - k) .. " " .. pt(x2, y1 + r),
        "l " .. pt(x2, y2 - r),
        "b " .. pt(x2, y2 - r + k) .. " " .. pt(x2 - r + k, y2) .. " " .. pt(x2 - r, y2),
        "l " .. pt(x1 + r, y2),
        "b " .. pt(x1 + r - k, y2) .. " " .. pt(x1, y2 - r + k) .. " " .. pt(x1, y2 - r),
        "l " .. pt(x1, y1 + r),
        "b " .. pt(x1, y1 + r - k) .. " " .. pt(x1 + r - k, y1) .. " " .. pt(x1 + r, y1),
    }, " ")
end

-- counter-clockwise twin of rrect, used to punch holes (non-zero fill rule)
function D.rrect_ccw(x1, y1, x2, y2, r)
    r = math.min(r, (x2 - x1) / 2, (y2 - y1) / 2)
    local k = 0.5523 * r
    return table.concat({
        "m " .. pt(x1 + r, y1),
        "b " .. pt(x1 + r - k, y1) .. " " .. pt(x1, y1 + r - k) .. " " .. pt(x1, y1 + r),
        "l " .. pt(x1, y2 - r),
        "b " .. pt(x1, y2 - r + k) .. " " .. pt(x1 + r - k, y2) .. " " .. pt(x1 + r, y2),
        "l " .. pt(x2 - r, y2),
        "b " .. pt(x2 - r + k, y2) .. " " .. pt(x2, y2 - r + k) .. " " .. pt(x2, y2 - r),
        "l " .. pt(x2, y1 + r),
        "b " .. pt(x2, y1 + r - k) .. " " .. pt(x2 - r + k, y1) .. " " .. pt(x2 - r, y1),
    }, " ")
end

function D.circle(cx, cy, r) return D.rrect(cx - r, cy - r, cx + r, cy + r, r) end

-- p = flat list {x1, y1, x2, y2, ...}
function D.poly(p)
    local out = { "m " .. pt(p[1], p[2]), "l" }
    for i = 3, #p, 2 do out[#out + 1] = pt(p[i], p[i + 1]) end
    return table.concat(out, " ")
end

-- color is an ASS color string like "&HBBGGRR&", op is opacity 0..1
function D.shape(cmds, color, op)
    if op < 0.01 then return nil end
    return fmt("{\\an7\\pos(0,0)\\bord0\\shad0\\1c%s\\1a&H%s&\\p1}%s{\\p0}", color, D.ahex(op), cmds)
end

function D.text(str, x, y, an, fs, color, op, font, extra)
    if op < 0.01 then return nil end
    return fmt("{\\an%d\\pos(%.1f,%.1f)\\fn%s\\fs%.1f%s\\bord0\\shad0\\1c%s\\1a&H%s&}%s",
        an, x, y, font, fs, extra or "", color, D.ahex(op), str)
end

return D
