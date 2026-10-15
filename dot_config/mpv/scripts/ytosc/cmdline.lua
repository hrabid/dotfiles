-- ":" command line: friendly shortcuts first, then any mpv command.
local TI = require 'textinput'
local S = require 'state'

local Cm = {}

local function toast(t) require('actions').toast(t) end

-- "1:30", "1:02:03", "90" -> seconds
local function hms(s)
    local total, ok = 0, false
    for part in s:gmatch("[^:]+") do
        local n = tonumber(part)
        if not n then return nil end
        total, ok = total * 60 + n, true
    end
    return ok and total or nil
end

local function seek(arg)
    local pct = arg:match("^([+-]?%d+%.?%d*)%%$")
    if pct then mp.commandv("seek", pct, "absolute-percent+exact"); return true end
    local sign, rest = arg:match("^([+-])(.+)$")
    local t = hms(sign and rest or arg)
    if not t then return false end
    if sign then mp.commandv("seek", tostring(sign == "-" and -t or t), "relative+exact")
    else mp.commandv("seek", tostring(t), "absolute+exact") end
    return true
end

function Cm.run(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return end
    local cmd, arg = text:match("^(%S+)%s*(.*)$")
    local O = function() return require('openers') end
    if cmd == "seek" or cmd == "s" then
        if not seek(arg) then toast("Usage: seek 1:30 | +10 | -10 | 50%") end
    elseif cmd == "speed" then
        local n = tonumber(arg)
        if n and n > 0 and n <= 100 then mp.set_property_number("speed", n) else toast("Usage: speed 1.5") end
    elseif cmd == "vol" or cmd == "volume" then
        local n = tonumber(arg)
        if n then mp.set_property_number("volume", n) else toast("Usage: vol 80") end
    elseif cmd == "chapter" then
        local n = tonumber(arg)
        if n then mp.set_property_number("chapter", n - 1) else toast("Usage: chapter 3") end
    elseif cmd == "open" or cmd == "e" then
        if arg ~= "" then O().open_paths({ arg }, false) else toast("Usage: open <path or URL>") end
    elseif cmd == "append" then
        if arg ~= "" then O().open_paths({ arg }, true) else toast("Usage: append <path or URL>") end
    elseif cmd == "q" or cmd == "quit" then mp.commandv("quit")
    elseif cmd == "wq" then mp.commandv("quit-watch-later")
    elseif not mp.command(text) then
        toast("Unknown command: " .. text)
    end
end

function Cm.open()
    TI.open({ prompt = ":", on_submit = Cm.run })
end

return Cm
