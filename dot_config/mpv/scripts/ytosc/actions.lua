local U = require 'util'
local S = require 'state'

local Act = {}
local undo, redo, marks = {}, {}, {}

local function cur() return mp.get_property_number("time-pos") end

function Act.toast(text, pos, dur)
    S.toast = { text = text, t_end = mp.get_time() + (dur or 1.0), pos = pos or "center" }
    S.cb.wake()
end

function Act.push_undo()
    local p = cur()
    if not p then return end
    undo[#undo + 1] = p
    if #undo > 50 then table.remove(undo, 1) end
    redo = {}
end

function Act.seek_rel(n)
    Act.push_undo()
    mp.commandv("seek", tostring(n), "relative+exact")
end

function Act.seek_abs(t)
    Act.push_undo()
    mp.commandv("seek", tostring(t), "absolute+exact")
end

function Act.volume_add(n)
    local vmax = mp.get_property_number("volume-max", 100)
    local v = U.clamp(mp.get_property_number("volume", 100) + n, 0, vmax)
    mp.set_property_number("volume", v)
    if n > 0 and mp.get_property_bool("mute") then mp.set_property_bool("mute", false) end
    Act.toast(string.format("Volume %d%%", math.floor(v + 0.5)), "center", 0.8)
end

local function jump(t) mp.commandv("seek", tostring(t), "absolute+exact") end

local function N(n) return n or 1 end

local function set_speed(v)
    v = U.clamp(v, 0.25, 4)
    mp.set_property_number("speed", v)
    Act.toast(string.format("Speed %sx", tostring(math.floor(v * 100 + 0.5) / 100)))
end

function Act.cc_toggle()
    if S.sub_count == 0 then Act.toast("No subtitles available"); return end
    if not S.sid then
        mp.commandv("cycle", "sub")
        mp.set_property_bool("sub-visibility", true)
        Act.toast("Subtitles on")
    else
        local v = not mp.get_property_bool("sub-visibility")
        mp.set_property_bool("sub-visibility", v)
        Act.toast(v and "Subtitles on" or "Subtitles off")
    end
end

-- Every action takes (count, char). count is nil when no count prefix was typed.
Act.table = {
    seek_back     = { fn = function(n) Act.seek_rel(-5 * N(n)) end },
    seek_fwd      = { fn = function(n) Act.seek_rel(5 * N(n)) end },
    seek_back_big = { fn = function(n) Act.seek_rel(-30 * N(n)) end },
    seek_fwd_big  = { fn = function(n) Act.seek_rel(30 * N(n)) end },
    seek_back_60  = { fn = function(n) Act.seek_rel(-60 * N(n)) end },
    seek_fwd_60   = { fn = function(n) Act.seek_rel(60 * N(n)) end },
    seek_back_300 = { fn = function(n) Act.seek_rel(-300 * N(n)) end },
    seek_fwd_300  = { fn = function(n) Act.seek_rel(300 * N(n)) end },
    goto_start    = { fn = function() Act.seek_abs(0) end },
    goto_end      = { fn = function()
        local d = mp.get_property_number("duration")
        if d then Act.seek_abs(math.max(0, d - 1)) end
    end },
    jump_percent  = { fn = function(n)
        if not n then Act.toast("Type a number first, e.g. 50%"); return end
        Act.push_undo()
        mp.commandv("seek", tostring(U.clamp(n, 0, 100)), "absolute-percent+exact")
    end },
    chapter_next  = { fn = function(n) Act.push_undo(); mp.commandv("add", "chapter", tostring(N(n))) end },
    chapter_prev  = { fn = function(n) Act.push_undo(); mp.commandv("add", "chapter", tostring(-N(n))) end },
    frame_fwd     = { fn = function() mp.commandv("frame-step") end },
    frame_back    = { fn = function() mp.commandv("frame-back-step") end },

    mark_set  = { needs_char = true, fn = function(_, ch)
        local p = cur()
        if p then marks[ch] = p; Act.toast("Mark " .. ch .. " set") end
    end },
    mark_jump = { needs_char = true, fn = function(_, ch)
        if marks[ch] then Act.seek_abs(marks[ch]) else Act.toast("No mark " .. ch) end
    end },

    undo_seek = { fn = function()
        local p = table.remove(undo)
        if not p then Act.toast("Nothing to undo"); return end
        local c = cur()
        if c then redo[#redo + 1] = c end
        jump(p)
    end },
    redo_seek = { fn = function()
        local p = table.remove(redo)
        if not p then Act.toast("Nothing to redo"); return end
        local c = cur()
        if c then undo[#undo + 1] = c end
        jump(p)
    end },

    pause = { fn = function() mp.commandv("cycle", "pause") end },
    speed_down = { fn = function() set_speed(mp.get_property_number("speed", 1) - 0.25) end },
    speed_up   = { fn = function() set_speed(mp.get_property_number("speed", 1) + 0.25) end },
    speed_reset = { fn = function() set_speed(1) end },

    playlist_next = { fn = function(n)
        for _ = 1, N(n) do mp.commandv("playlist-next", "weak") end
    end },
    playlist_prev = { fn = function(n)
        for _ = 1, N(n) do mp.commandv("playlist-prev", "weak") end
    end },

    volume_up   = { fn = function(n) Act.volume_add(5 * N(n)) end },
    volume_down = { fn = function(n) Act.volume_add(-5 * N(n)) end },
    mute = { fn = function()
        mp.commandv("cycle", "mute")
        Act.toast(mp.get_property_bool("mute") and "Muted" or "Unmuted", "center", 0.8)
    end },

    sub_toggle = { fn = function() Act.cc_toggle() end },
    theater_toggle = { fn = function() require('view').toggle("theater") end },
    mini_toggle = { fn = function() require('view').toggle("mini") end },
    command_line = { fn = function() require('cmdline').open() end },
    open_menu = { fn = function() require('menus').open("open") end },
    open_dir = { fn = function() require('openers').pick_dir(false) end },
    paste_play = { fn = function() require('openers').paste(false) end },
    paste_append = { fn = function() require('openers').paste(true) end },
    panel_toggle = { fn = function() require('panel').toggle() end },
    strip_toggle = { fn = function() require('strip').toggle() end },
    settings_toggle = { fn = function() require('menus').toggle() end },
    sub_cycle = { fn = function()
        mp.commandv("cycle", "sub")
        Act.toast("Subtitle track: " .. tostring(mp.get_property("sid")))
    end },
    audio_cycle = { fn = function()
        mp.commandv("cycle", "audio")
        Act.toast("Audio track: " .. tostring(mp.get_property("aid")))
    end },

    fullscreen = { fn = function() mp.commandv("cycle", "fullscreen") end },
    escape = { fn = function()
        if S.input then require('textinput').close()
        elseif S.menu then require('menus').close()
        elseif S.panel then require('panel').close()
        elseif S.strip then require('strip').close()
        elseif mp.get_property_bool("fullscreen") then mp.set_property_bool("fullscreen", false) end
    end },
    toggle_remaining = { fn = function() S.remaining = not S.remaining; S.cb.dirty() end },
    stats = { fn = function() mp.commandv("script-binding", "stats/display-stats-toggle") end },

    quit = { fn = function() mp.commandv("quit") end },
    quit_watch_later = { fn = function() mp.commandv("quit-watch-later") end },
    quit_nosave = { fn = function() mp.commandv("quit") end },
}

return Act
