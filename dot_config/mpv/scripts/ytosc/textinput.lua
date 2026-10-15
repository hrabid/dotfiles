-- Single-line text input widget (rendered by render.lua, edited here).
local S = require 'state'

local TI = {}
local KEYS = { "BS", "DEL", "LEFT", "RIGHT", "HOME", "END", "ENTER", "KP_ENTER", "ESC", "Ctrl+w", "Ctrl+u", "Ctrl+v" }

local function prev_pos(t, i)
    local j = i
    while j > 0 do
        local b = t:byte(j)
        j = j - 1
        if b < 0x80 or b >= 0xC0 then break end
    end
    return j
end

local function next_pos(t, i)
    if i >= #t then return i end
    local b = t:byte(i + 1)
    local len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
    return math.min(#t, i + len)
end

function TI.active() return S.input ~= nil end

function TI.insert(str)
    local inp = S.input
    if not inp or not str or str == "" then return end
    inp.text = inp.text:sub(1, inp.caret) .. str .. inp.text:sub(inp.caret + 1)
    inp.caret = inp.caret + #str
    if inp.on_change then inp.on_change(inp.text) end
    S.cb.wake()
end

function TI.close()
    if not S.input then return end
    for _, k in ipairs(KEYS) do mp.remove_key_binding("ytosc-ti-" .. k) end
    mp.remove_key_binding("ytosc-ti-text")
    S.input, S.input_focus = nil, false
    S.cb.wake()
end

local function submit()
    local inp = S.input
    local cb, text = inp.on_submit, inp.text
    TI.close()
    if cb then cb(text) end
end

local function handle(k)
    local inp = S.input
    if not inp then return end
    local t, c = inp.text, inp.caret
    if k == "ENTER" or k == "KP_ENTER" then submit(); return
    elseif k == "ESC" then
        local cb = inp.on_cancel
        TI.close()
        if cb then cb() end
        return
    elseif k == "BS" then
        local p = prev_pos(t, c)
        inp.text, inp.caret = t:sub(1, p) .. t:sub(c + 1), p
    elseif k == "DEL" then
        local n = next_pos(t, c)
        inp.text = t:sub(1, c) .. t:sub(n + 1)
    elseif k == "LEFT" then inp.caret = prev_pos(t, c)
    elseif k == "RIGHT" then inp.caret = next_pos(t, c)
    elseif k == "HOME" then inp.caret = 0
    elseif k == "END" then inp.caret = #t
    elseif k == "Ctrl+u" then
        inp.text, inp.caret = t:sub(c + 1), 0
    elseif k == "Ctrl+w" then
        local before = t:sub(1, c)
        local s = before:find("%S*%s*$")
        inp.text, inp.caret = before:sub(1, s - 1) .. t:sub(c + 1), s - 1
    elseif k == "Ctrl+v" then
        local clip = mp.get_property("clipboard/text")
        if clip and clip ~= "" then TI.insert((clip:match("[^\r\n]*"))) end
        return
    end
    if inp.on_change then inp.on_change(inp.text) end
    S.cb.wake()
end

-- keys that ytosc itself binds reach us here instead of through any_unicode
function TI.key_token(tok)
    if tok == "SPACE" then TI.insert(" ")
    elseif #tok == 1 then TI.insert(tok) end
end

function TI.open(opts)
    if S.input then TI.close() end
    local text = opts.text or ""
    S.input = {
        prompt = opts.prompt or "", text = text, caret = #text,
        on_submit = opts.on_submit, on_cancel = opts.on_cancel, on_change = opts.on_change,
    }
    S.input_focus = true
    for _, k in ipairs(KEYS) do
        mp.add_forced_key_binding(k, "ytosc-ti-" .. k, function() handle(k) end, { repeatable = true })
    end
    mp.add_forced_key_binding("any_unicode", "ytosc-ti-text", function(e)
        if e.key_text and (e.event == "press" or e.event == "down" or e.event == "repeat") then
            TI.insert(e.key_text)
        end
    end, { repeatable = true, complex = true })
    S.cb.show()
    S.cb.wake()
end

return TI
