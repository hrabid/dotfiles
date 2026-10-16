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
-- Asks the desktop's own file chooser (xdg-desktop-portal, the same dialog browsers and
-- Celluloid use) through gdbus. Exit codes: 0 = chose something (paths on stdout, one per line),
-- 1 = cancelled, 2 = portal not available (the next picker is tried).
local PORTAL_SCRIPT = [==[
kind="$1"
command -v gdbus >/dev/null 2>&1 || exit 2
command -v dbus-monitor >/dev/null 2>&1 || exit 2
tok="ytosc${$}x${RANDOM}"
out=$(mktemp) || exit 2
# The portal answers only the program that asked, so a monitor (which sees every message on
# the session bus) is used to read the reply.
dbus-monitor --session "type='signal',interface='org.freedesktop.portal.Request',member='Response'" >"$out" 2>/dev/null &
mon=$!
trap 'kill "$mon" 2>/dev/null; rm -f "$out"' EXIT
sleep 0.4
if [ "$kind" = dir ]; then
  title="Open folder"; opts="{'handle_token': <'$tok'>, 'directory': <true>}"
else
  title="Open"; opts="{'handle_token': <'$tok'>, 'multiple': <true>}"
fi
gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.FileChooser.OpenFile "" "$title" "$opts" >/dev/null 2>&1 || exit 2
while ! grep -q "/$tok;" "$out" 2>/dev/null; do
  kill -0 "$mon" 2>/dev/null || exit 2
  sleep 0.1
done
sleep 0.3
block=$(awk -v t="/$tok;" 'index($0, t) { on = 1; next } on && /^(signal|method|error)/ { exit } on { print }' "$out")
code=$(printf '%s\n' "$block" | grep -m1 -o 'uint32 [0-9]*' | cut -d' ' -f2)
case "$code" in
  0) ;;
  1) exit 1 ;;
  *) exit 2 ;;
esac
printf '%s\n' "$block" | grep -o 'string "file://[^"]*"' | while IFS= read -r u; do
  u=${u#string \"file://}
  u=${u%\"}
  printf '%b\n' "${u//%/\\x}"
done
]==]

local PORTAL_PY = [==[
import os, sys, socket, struct, binascii, urllib.parse, time

kind = sys.argv[1] if len(sys.argv) > 1 else "file"

def die(code, msg):
    sys.stderr.write(msg + "\n")
    sys.exit(code)

# ---------------------------------------------------------------- marshalling
class W:
    def __init__(self): self.b = bytearray()
    def align(self, n): self.b += b"\0" * ((-len(self.b)) % n)
    def u32(self, v): self.align(4); self.b += struct.pack("<I", v)
    def s(self, v):
        e = v.encode(); self.u32(len(e)); self.b += e + b"\0"
    def g(self, v):
        e = v.encode(); self.b.append(len(e)); self.b += e + b"\0"

def w_array(w, align, body_fn):
    w.align(4)
    len_pos = len(w.b)
    w.b += b"\0\0\0\0"
    w.align(align)
    start = len(w.b)
    body_fn()
    w.b[len_pos:len_pos + 4] = struct.pack("<I", len(w.b) - start)

def build(mtype, serial, fields, body=b"", sig=""):
    w = W()
    w.b += b"l" + bytes([mtype, 0, 1]) + struct.pack("<I", len(body)) + struct.pack("<I", serial)
    def write_fields():
        for code, kind_, val in fields:
            w.align(8); w.b.append(code); w.g(kind_)
            if kind_ == "u": w.u32(val)
            elif kind_ == "g": w.g(val)
            else: w.s(val)
    if sig: fields = fields + [(8, "g", sig)]
    w_array(w, 8, write_fields)
    w.align(8)
    w.b += body
    return bytes(w.b)

class R:
    def __init__(self, data, pos=0): self.d, self.p = data, pos
    def align(self, n): self.p += (-self.p) % n
    def take(self, fmt, n):
        self.align(n); v = struct.unpack_from("<" + fmt, self.d, self.p)[0]; self.p += n; return v
    def string(self, long=True):
        if long: n = self.take("I", 4)
        else: n = self.d[self.p]; self.p += 1
        v = self.d[self.p:self.p + n].decode(errors="replace"); self.p += n + 1; return v

def parse_one(r, sig, i):
    c = sig[i]
    if c == "y":
        v = r.d[r.p]; r.p += 1; return v, i + 1
    if c == "b": return bool(r.take("I", 4)), i + 1
    if c in "nq": return r.take("h" if c == "n" else "H", 2), i + 1
    if c in "iu": return r.take("i" if c == "i" else "I", 4), i + 1
    if c in "xt": return r.take("q" if c == "x" else "Q", 8), i + 1
    if c == "d": return r.take("d", 8), i + 1
    if c == "h": return r.take("I", 4), i + 1
    if c in "so": return r.string(), i + 1
    if c == "g": return r.string(False), i + 1
    if c == "v":
        s = r.string(False); v, _ = parse_one(r, s, 0); return v, i + 1
    if c == "a":
        n = r.take("I", 4)
        elem_start = i + 1
        end_i = skip(sig, elem_start)
        r.align(8 if sig[elem_start] in "({" else {"y": 1, "b": 4, "n": 2, "q": 2, "i": 4, "u": 4, "x": 8, "t": 8, "d": 8, "s": 4, "o": 4, "g": 1, "a": 4, "v": 1, "h": 4}[sig[elem_start]])
        stop = r.p + n; out = []
        while r.p < stop:
            v, _ = parse_one(r, sig, elem_start); out.append(v)
        return out, end_i
    if c in "({":
        r.align(8); vals = []; j = i + 1
        while sig[j] not in ")}":
            v, j = parse_one(r, sig, j); vals.append(v)
        return tuple(vals), j + 1
    raise ValueError("unsupported type " + c)

def skip(sig, i):
    c = sig[i]
    if c == "a": return skip(sig, i + 1)
    if c in "({":
        j = i + 1
        while sig[j] not in ")}": j = skip(sig, j)
        return j + 1
    return i + 1

def parse_body(sig, data, pos):
    r, out, i = R(data, pos), [], 0
    while i < len(sig):
        v, i = parse_one(r, sig, i); out.append(v)
    return out

# ----------------------------------------------------------------- connection
addr = os.environ.get("DBUS_SESSION_BUS_ADDRESS") or "unix:path=/run/user/%d/bus" % os.getuid()
path = None
for part in addr.split(";"):
    if part.startswith("unix:"):
        for kv in part[5:].split(","):
            if kv.startswith("path="): path = kv[5:]
            elif kv.startswith("abstract="): path = "\0" + kv[9:]
        break
if not path: die(2, "no session bus address")
sock = socket.socket(socket.AF_UNIX)
sock.settimeout(10)
try:
    sock.connect(path)
    sock.sendall(b"\0AUTH EXTERNAL " + binascii.hexlify(str(os.getuid()).encode()) + b"\r\n")
    line = b""
    while not line.endswith(b"\r\n"): line += sock.recv(1)
    if not line.startswith(b"OK"): die(2, "bus auth failed: %r" % line)
    sock.sendall(b"BEGIN\r\n")
except OSError as e:
    die(2, "cannot connect to the session bus: %s" % e)

buf = b""
def recv_msg(timeout=None):
    global buf
    sock.settimeout(timeout)
    while True:
        if len(buf) >= 16:
            blen, flen = struct.unpack_from("<I", buf, 4)[0], struct.unpack_from("<I", buf, 12)[0]
            hlen = 16 + flen; hlen += (-hlen) % 8
            if len(buf) >= hlen + blen:
                msg, buf = buf[:hlen + blen], buf[hlen + blen:]
                mtype = msg[1]; fields = {}
                r = R(msg, 12); n = r.take("I", 4); r.align(8); stop = r.p + n
                while r.p < stop:
                    r.align(8); code = msg[r.p]; r.p += 1
                    s = r.string(False)
                    v, _ = parse_one(r, s, 0)
                    fields[code] = v
                return mtype, fields, msg, hlen
        chunk = sock.recv(65536)
        if not chunk: die(2, "bus connection closed")
        buf += chunk

serial = [0]
def call(dest, path_, iface, member, sig="", body=b""):
    serial[0] += 1
    f = [(1, "o", path_), (2, "s", iface), (3, "s", member), (6, "s", dest)]
    sock.sendall(build(1, serial[0], f, body, sig))
    me = serial[0]
    while True:
        mtype, fields, msg, hlen = recv_msg(10)
        if fields.get(5) == me:
            if mtype == 3: die(2, "%s: %s" % (fields.get(4), (parse_body(fields.get(8, ""), msg, hlen) or [""])[0]))
            return fields, msg, hlen

# Hello -> our unique name
f, msg, hlen = call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "Hello")
me = parse_body("s", msg, hlen)[0]
token = "ytosc%dx%d" % (os.getpid(), int(time.time() * 1000) % 100000)
req = "/org/freedesktop/portal/desktop/request/%s/%s" % (me[1:].replace(".", "_"), token)

# listen for the answer on THIS connection before asking
w = W(); w.s("type='signal',interface='org.freedesktop.portal.Request',member='Response',path='%s'" % req)
call("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "AddMatch", "s", bytes(w.b))

# OpenFile("", title, {handle_token, multiple | directory})
w = W(); w.s(""); w.s("Open folder" if kind == "dir" else "Open")
def opts():
    w.align(8); w.s("handle_token"); w.g("s"); w.s(token)
    w.align(8); w.s("directory" if kind == "dir" else "multiple"); w.g("b"); w.u32(1)
w_array(w, 8, opts)
call("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop", "org.freedesktop.portal.FileChooser", "OpenFile", "ssa{sv}", bytes(w.b))

# wait (as long as the dialog is open) for the Response signal
while True:
    mtype, fields, msg, hlen = recv_msg(None)
    if mtype == 4 and fields.get(1) == req and fields.get(3) == "Response":
        code, results = parse_body("ua{sv}", msg, hlen)
        if code == 1: sys.exit(1)
        if code != 0: die(3, "portal answered with code %d" % code)
        uris = []
        for k, v in results: 
            if k == "uris": uris = v
        if not uris: die(3, "portal returned no files: %r" % (results,))
        for u in uris:
            if u.startswith("file://"): print(urllib.parse.unquote(u[7:]))
            else: print(u)
        sys.exit(0)

]==]

local function candidates(kind)
    local custom = kind == "file" and C.picker_file or C.picker_dir
    if custom ~= "" then return { { name = "custom", args = U.split(custom) } } end
    local want, list = C.picker, {}
    local home = os.getenv("HOME") or "/"
    local function add(name, args)
        if want == "auto" or want == name or (want == "portal" and name:find("^portal")) then
            list[#list + 1] = { name = name, args = args }
        end
    end
    if want == "prompt" then return list end
    if O.which("python3") then
        add("portal", { "python3", "-c", PORTAL_PY, kind })
    end
    if O.which("gdbus") and O.which("dbus-monitor") and O.which("bash") then
        add("portal-sh", { "bash", "-c", PORTAL_SCRIPT, "ytosc-portal", kind })
    end
    if O.which("zenity") then
        add("zenity", kind == "file"
            and { "zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Open" }
            or { "zenity", "--file-selection", "--directory", "--title=Open folder" })
    end
    if O.which("kdialog") then
        add("kdialog", kind == "file"
            and { "kdialog", "--getopenfilename", home, "--multiple", "--separate-output" }
            or { "kdialog", "--getexistingdirectory", home })
    end
    if O.which("yad") then
        add("yad", kind == "file" and { "yad", "--file", "--multiple", "--separator=\n" }
            or { "yad", "--file", "--directory" })
    end
    return list
end

-- cb receives a list of paths (never called when the chooser is cancelled).
-- Tries the system file chooser first, then zenity / kdialog / yad, and only as a last
-- resort asks you to type the path.
function O.pick(kind, cb)
    local list = candidates(kind)
    local function prompt()
        if C.picker ~= "prompt" and C.picker_file == "" then
            toast("No file chooser found. Install xdg-desktop-portal-gtk or zenity (see README)")
        end
        TI.open({ prompt = kind == "file" and "Path" or "Folder", on_submit = function(t)
            t = t:match("^%s*(.-)%s*$")
            if t ~= "" then cb({ t }) end
        end })
    end
    local function try(i)
        local c = list[i]
        if not c then prompt(); return end
        mp.command_native_async({ name = "subprocess", args = c.args, capture_stdout = true, capture_stderr = true,
            playback_only = false },
            function(ok, res)
                local status = ok and res and res.status
                local err = ok and res and res.stderr and res.stderr:gsub("%s+$", "") or ""
                if status == 0 then
                    local out = {}
                    for line in (res.stdout or ""):gmatch("[^\r\n]+") do out[#out + 1] = line end
                    msg.verbose("file chooser '" .. c.name .. "' returned " .. #out .. " path(s)")
                    if #out > 0 then
                        for _, pth in ipairs(out) do msg.verbose("chosen: " .. pth) end
                        cb(out)
                    else
                        toast("The file chooser returned no file (run mpv with --msg-level=ytosc=v for details)")
                    end
                elseif status == 1 then
                    msg.verbose("file chooser '" .. c.name .. "' was cancelled")
                elseif status == 3 then
                    msg.warn("file chooser '" .. c.name .. "' gave an unexpected answer: " .. err)
                    toast("The file chooser gave an unexpected answer (see the mpv log)")
                else
                    msg.verbose("file chooser '" .. c.name .. "' not available (status " .. tostring(status) .. "): " .. err)
                    try(i + 1)
                end
            end)
    end
    try(1)
end

O._portal_script = PORTAL_SCRIPT

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
