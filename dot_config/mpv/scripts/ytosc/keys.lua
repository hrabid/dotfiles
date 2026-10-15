-- Vim-style key dispatcher: count prefix, multi-key chords, char arguments.
local U = require 'util'
local S = require 'state'
local C = require 'config'
local Act = require 'actions'
local msg = require 'mp.msg'

local K = {}

-- sequences are space-separated mpv key names
local DEFAULT = {
    h = "seek_back", l = "seek_fwd", H = "seek_back_big", L = "seek_fwd_big",
    ["Ctrl+d"] = "seek_fwd_60", ["Ctrl+u"] = "seek_back_60",
    ["Ctrl+f"] = "seek_fwd_300", ["Ctrl+b"] = "seek_back_300",
    ["g g"] = "goto_start", G = "goto_end", ["%"] = "jump_percent",
    w = "chapter_next", b = "chapter_prev",
    [","] = "frame_back", ["."] = "frame_fwd",
    m = "mark_set", ["'"] = "mark_jump",
    u = "undo_seek", ["Ctrl+r"] = "redo_seek",
    SPACE = "pause", ["["] = "speed_down", ["]"] = "speed_up", ["="] = "speed_reset",
    J = "playlist_next", K = "playlist_prev",
    k = "volume_up", j = "volume_down", M = "mute",
    c = "sub_toggle", C = "sub_cycle", a = "audio_cycle",
    f = "fullscreen", t = "toggle_remaining", i = "stats",
    q = "quit", ["Z Z"] = "quit_watch_later", ["Z Q"] = "quit_nosave",
    ESC = "escape", s = "settings_toggle", TAB = "panel_toggle", v = "strip_toggle",
    T = "theater_toggle", I = "mini_toggle", [":"] = "command_line", o = "open_menu", O = "open_dir", p = "paste_play", P = "paste_append",
}

local map, prefixes, tokens = {}, {}, {}
local count, seq, await_fn, timer = "", {}, nil, nil
local on_key

local function build()
    map, prefixes, tokens = {}, {}, {}
    for k, v in pairs(DEFAULT) do map[k] = v end

    local path = mp.command_native({ "expand-path", C.keys_file })
    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            line = line:gsub("^%s+", "")
            if line ~= "" and line:sub(1, 1) ~= ";" then
                local key, action = line:match("^(.-)%s*=%s*([%w_]+)%s*$")
                if key and key ~= "" then
                    key = table.concat(U.split(key), " ")
                    if action == "none" then map[key] = nil
                    elseif Act.table[action] then map[key] = action
                    else msg.warn("unknown action '" .. action .. "' in keys file") end
                end
            end
        end
        f:close()
    end

    for key in pairs(map) do
        local toks = U.split(key)
        for i = 1, #toks - 1 do prefixes[table.concat(toks, " ", 1, i)] = true end
        for _, t in ipairs(toks) do tokens[t] = true end
    end
    for d = 0, 9 do tokens[tostring(d)] = true end
end

local function unbind_chars()
    for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
        mp.remove_key_binding("ytosc-await-" .. c)
    end
end

local function bind_chars()
    for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
        mp.add_forced_key_binding(c, "ytosc-await-" .. c, function() on_key(c) end)
    end
end

local function set_pending()
    local s = count .. table.concat(seq, "")
    if await_fn then s = s .. "_" end
    S.pending = s
    S.cb.wake()
end

local function disarm()
    if timer then timer:kill(); timer = nil end
end

local function clear()
    count, seq, await_fn = "", {}, nil
    unbind_chars()
    disarm()
    if S.pending ~= "" then S.pending = ""; S.cb.dirty() end
end

local function arm(secs)
    disarm()
    timer = mp.add_timeout(secs or (C.timeoutlen / 1000), function()
        timer = nil
        if await_fn then clear(); return end
        local exact = map[table.concat(seq, " ")]
        if exact then K.run(exact) else clear() end
    end)
end

function K.run(action)
    local n = tonumber(count)
    local a = Act.table[action]
    count, seq = "", {}
    disarm()
    if not a then clear(); return end
    if a.needs_char then
        await_fn = function(ch) a.fn(n, ch) end
        bind_chars()
        set_pending()
        arm(2)
        return
    end
    if S.pending ~= "" then S.pending = ""; S.cb.dirty() end
    a.fn(n)
end

on_key = function(tok)
    if S.input_focus then require('textinput').key_token(tok); return end
    if S.menu and require('menus').on_key(tok) then return end
    if await_fn then
        local fn = await_fn
        clear()
        fn(tok)
        return
    end
    if #seq == 0 and tok:match("^%d$") and (tok ~= "0" or count ~= "") then
        count = count .. tok
        set_pending()
        arm()
        return
    end
    seq[#seq + 1] = tok
    local key = table.concat(seq, " ")
    local exact, longer = map[key], prefixes[key]
    if exact and not longer then
        K.run(exact)
    elseif longer then
        set_pending()
        arm()
    else
        local had = #seq
        clear()
        if had > 1 then on_key(tok) end
    end
end

function K.init()
    if C.keymap == "mpv" then return end
    build()
    for tok in pairs(tokens) do
        mp.add_forced_key_binding(tok, "ytosc-key-" .. tok, function() on_key(tok) end, { repeatable = true })
    end
end

-- exposed for tests
K._on_key = function(tok) on_key(tok) end

return K
