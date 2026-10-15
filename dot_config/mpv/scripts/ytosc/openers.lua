-- Opening media: files, folders (as playlists), URLs, clipboard, recent files.
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local C = require 'config'
local U = require 'util'
local TI = require 'textinput'

local O = { history = {} }
local exts

local function toast(t) require('actions').toast(t) end

local function ext_set()
    if exts then return exts end
    exts = {}
    for e in C.media_extensions:gmatch("[^,%s]+") do exts[e:lower()] = true end
    return exts
end

local function natural_key(s)
    return (s:lower():gsub("%d+", function(n)
        if #n < 20 then return string.rep("0", 20 - #n) .. n end
        return n
    end))
end

local function natural_less(a, b) return natural_key(a) < natural_key(b) end

function O.is_url(p) return p:match("^%a[%w+.-]*://") ~= nil end

function O.abs(p)
    if p == "" or O.is_url(p) or p:sub(1, 1) == "/" then return p end
    return utils.join_path(mp.get_property("working-directory") or ".", p)
end

function O.dir_of(path)
    local d = utils.split_path(path)
    d = d:gsub("/+$", "")
    if d == "" then d = "/" end
    return d
end

local function basename(p) return p:match("([^/]+)$") or p end

function O.which(name)
    for dir in (os.getenv("PATH") or ""):gmatch("[^:]+") do
        local i = utils.file_info(dir .. "/" .. name)
        if i and i.is_file then return true end
    end
    return false
end

---------------------------------------------------------------- directories
function O.sorted_media(dir, recursive)
    local out, keep, set = {}, {}, ext_set()
    for _, f in ipairs(utils.readdir(dir, "files") or {}) do
        local e = f:match("%.([^.]+)$")
        if e and set[e:lower()] then keep[#keep + 1] = f end
    end
    table.sort(keep, natural_less)
    for _, f in ipairs(keep) do out[#out + 1] = utils.join_path(dir, f) end
    if recursive then
        local dirs = {}
        for _, d in ipairs(utils.readdir(dir, "dirs") or {}) do
            if d:sub(1, 1) ~= "." then dirs[#dirs + 1] = d end
        end
        table.sort(dirs, natural_less)
        for _, d in ipairs(dirs) do
            for _, p in ipairs(O.sorted_media(utils.join_path(dir, d), true)) do out[#out + 1] = p end
        end
    end
    return out
end

------------------------------------------------------------------- loading
function O.load(paths, append)
    if #paths == 0 then return end
    local first = 1
    if not append then
        mp.commandv("loadfile", paths[1], "replace")
        first = 2
    end
    for i = first, #paths do mp.commandv("loadfile", paths[i], "append") end
    if append then toast(string.format("Added %d item%s", #paths, #paths == 1 and "" or "s")) end
end

-- one local file + autoload_dir: its siblings become the playlist, playback starts at that file
function O.open_paths(paths, append)
    if #paths == 0 then return end
    if #paths == 1 and not append and C.autoload_dir and not O.is_url(paths[1]) then
        local p = O.abs(paths[1])
        local info = utils.file_info(p)
        if info and info.is_file then
            local sib = O.sorted_media(O.dir_of(p), false)
            local idx
            for i, s in ipairs(sib) do
                if basename(s) == basename(p) then idx = i end
            end
            if idx and #sib > 1 then
                mp.commandv("loadfile", p, "replace")
                for i, s in ipairs(sib) do
                    if i ~= idx then mp.commandv("loadfile", s, "append") end
                end
                if idx > 1 then mp.commandv("playlist-move", "0", tostring(idx)) end
                return
            end
        end
    end
    O.load(paths, append)
end

function O.open_dir(dir, append)
    local list = O.sorted_media(dir, C.recursive_dir)
    if #list == 0 then toast("No media files in that folder"); return end
    O.load(list, append)
end

---------------------------------------------------------------- pickers
local function picker_cmd(kind)
    local custom = kind == "file" and C.picker_file or C.picker_dir
    if custom ~= "" then return U.split(custom) end
    local home = os.getenv("HOME") or "/"
    if O.which("zenity") then
        if kind == "file" then return { "zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Open" } end
        return { "zenity", "--file-selection", "--directory", "--title=Open folder" }
    elseif O.which("kdialog") then
        if kind == "file" then return { "kdialog", "--getopenfilename", home, "--multiple", "--separate-output" } end
        return { "kdialog", "--getexistingdirectory", home }
    elseif O.which("yad") then
        if kind == "file" then return { "yad", "--file", "--multiple", "--separator=\n" } end
        return { "yad", "--file", "--directory" }
    end
end

-- cb receives a list of paths (never called when the picker is cancelled)
function O.pick(kind, cb)
    local cmd = picker_cmd(kind)
    if not cmd then
        TI.open({ prompt = kind == "file" and "Path" or "Folder", on_submit = function(t)
            t = t:match("^%s*(.-)%s*$")
            if t ~= "" then cb({ t }) end
        end })
        return
    end
    mp.command_native_async({ name = "subprocess", args = cmd, capture_stdout = true, playback_only = false },
        function(ok, res)
            if not ok or not res or res.status ~= 0 then return end
            local out = {}
            for line in (res.stdout or ""):gmatch("[^\r\n]+") do out[#out + 1] = line end
            if #out > 0 then cb(out) end
        end)
end

function O.pick_files(append) O.pick("file", function(l) O.open_paths(l, append) end) end
function O.pick_dir(append) O.pick("dir", function(l) O.open_dir(l[1], append) end) end

function O.prompt(append)
    TI.open({ prompt = append and "Add URL or path" or "URL or path", on_submit = function(t)
        t = t:match("^%s*(.-)%s*$")
        if t ~= "" then O.open_paths({ t }, append) end
    end })
end

function O.clipboard(cb)
    local p = mp.get_property("clipboard/text")
    if p and p ~= "" then cb(p); return end
    local cmd
    if O.which("wl-paste") then cmd = { "wl-paste", "-n" }
    elseif O.which("xclip") then cmd = { "xclip", "-o", "-selection", "clipboard" } end
    if not cmd then cb(nil); return end
    mp.command_native_async({ name = "subprocess", args = cmd, capture_stdout = true, playback_only = false },
        function(ok, res) cb((ok and res and res.status == 0) and res.stdout or nil) end)
end

function O.paste(append)
    O.clipboard(function(t)
        local line = (t or ""):match("[^\r\n]+")
        line = line and line:match("^%s*(.-)%s*$")
        if not line or line == "" then toast("Clipboard is empty"); return end
        O.open_paths({ line }, append)
    end)
end

------------------------------------------------------------------ history
local hist_path, dir_made

local function hp()
    if not hist_path then hist_path = mp.command_native({ "expand-path", "~~state/ytosc-history" }) end
    return hist_path
end

function O.load_history()
    O.history = {}
    local f = io.open(hp(), "r")
    if not f then return end
    for l in f:lines() do
        if l ~= "" then O.history[#O.history + 1] = l end
    end
    f:close()
end

function O.record(path)
    path = O.abs(path or mp.get_property("path") or "")
    if path == "" then return end
    local list = { path }
    for _, p in ipairs(O.history) do
        if p ~= path and #list < 20 then list[#list + 1] = p end
    end
    O.history = list
    if not dir_made then
        mp.command_native({ name = "subprocess", args = { "mkdir", "-p", O.dir_of(hp()) }, playback_only = false })
        dir_made = true
    end
    local f = io.open(hp(), "w")
    if not f then msg.warn("cannot write history file"); return end
    f:write(table.concat(list, "\n"), "\n")
    f:close()
end

O.basename = basename
return O
