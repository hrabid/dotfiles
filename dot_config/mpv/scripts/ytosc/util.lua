local U = {}

function U.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

function U.lerp(a, b, t) return a + (b - a) * t end

-- ease-out cubic
function U.ease(t)
    if t <= 0 then return 0 elseif t >= 1 then return 1 end
    local u = 1 - t
    return 1 - u * u * u
end

function U.fmt_time(t)
    if not t or t ~= t or t < 0 then t = 0 end
    t = math.floor(t)
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

-- rough text width estimate (no font metrics available in ASS land)
function U.text_w(str, fs)
    local n = select(2, str:gsub("[^\128-\191]", ""))
    return n * fs * 0.55
end

function U.ellipsize(str, maxw, fs)
    if U.text_w(str, fs) <= maxw then return str end
    local chars = {}
    for ch in str:gmatch("[\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    while #chars > 0 and U.text_w(table.concat(chars), fs) + fs * 0.55 > maxw do table.remove(chars) end
    return table.concat(chars) .. "\226\128\166"
end

-- split into at most two lines that fit maxw (second line ellipsized)
function U.wrap2(str, maxw, fs)
    if U.text_w(str, fs) <= maxw then return str, "" end
    local chars = {}
    for ch in str:gmatch("[\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    local n = #chars
    while n > 0 and U.text_w(table.concat(chars, "", 1, n), fs) > maxw do n = n - 1 end
    -- prefer breaking at a space close to the limit
    local cut = n
    for i = n, math.max(1, n - 12), -1 do
        if chars[i] == " " then cut = i; break end
    end
    local first = table.concat(chars, "", 1, cut)
    local rest = table.concat(chars, "", cut + 1):gsub("^%s+", "")
    return first, U.ellipsize(rest, maxw, fs)
end

function U.split(s)
    local t = {}
    for tok in s:gmatch("%S+") do t[#t + 1] = tok end
    return t
end

return U
