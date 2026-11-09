#!/usr/bin/env python3
"""Waybar system monitor: compact pill + detailed hover tooltip. Python stdlib only.

Runs continuously (waybar "exec" without "interval") and prints one JSON line
per update, so CPU rates are computed from in-memory deltas. Network details
live in waybar's own network module tooltip, not here.
"""
import glob
import html
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time

INTERVAL = 2      # seconds between updates
SHOW_GPU = False  # live GPU sensors; can keep a hybrid-graphics dGPU awake (the GPU *model* is always shown)
MAX_DISKS = 4
TOP_PROCS = 7     # processes listed in the tooltip (0 disables)
GRID_FONT = "JetBrainsMono Nerd Font"  # monospace, only for the per-core grid

# Nerd Font (Material Design) icons
CPU, MEM, DISK, TEMP, POWER, TOP = (
    chr(c) for c in (0xF061A, 0xF035B, 0xF02CA, 0xF050F, 0xF0241, 0xF04C5))
DISTRO_ICONS = {"arch": "\uf303", "endeavouros": "\uf322", "manjaro": "\uf312", "cachyos": "\uf303",
                "debian": "\uf306", "ubuntu": "\uf31b", "fedora": "\uf30a", "nixos": "\uf313"}
GENERIC_ICON = "\uf17c"
SPARK = "▁▂▃▄▅▆▇█"
CLK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")


# ── helpers ──────────────────────────────────────────────────────────────────

def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def num(path):
    try:
        return float(read(path))
    except (TypeError, ValueError):
        return None


def esc(text):
    return html.escape(str(text))


def dim(text):
    return f"<span alpha='65%'>{text}</span>"


def bar(pct, width=10):
    n = max(0, min(width, round(pct / 100 * width)))
    return "▰" * n + "▱" * (width - n)


def size(b):
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if b < 1024 or unit == "TiB":
            return f"{b:.0f} B" if unit == "B" else f"{b:.1f} {unit}"
        b /= 1024


def hm(hours):
    m = round(hours * 60)
    return f"{m // 60}h {m % 60:02d}m"


def uptime():
    s = int(float(read("/proc/uptime", "0").split()[0]))
    d, s = divmod(s, 86400)
    h, s = divmod(s, 3600)
    return (f"{d}d " if d else "") + f"{h}h {s // 60:02d}m"


def run(cmd, timeout=2):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def info_row(label, value):
    return f"    {dim(label)}  {esc(value)}"


# ── static system info (collected once at start) ─────────────────────────────

PLACEHOLDERS = {"", "none", "default string", "to be filled by o.e.m.", "system version",
                "system product name", "not specified", "not applicable", "1.0", "n/a"}


def dmi(name):
    v = read(f"/sys/class/dmi/id/{name}", "")
    return "" if v.strip().lower() in PLACEHOLDERS else v.strip()


def host_model():
    vendor = dmi("sys_vendor")
    # Lenovo keeps the marketing name in product_version, the rest in product_name/family
    order = ("product_version", "product_name", "product_family") if "lenovo" in vendor.lower() \
        else ("product_name", "product_family", "product_version")
    name = next((dmi(k) for k in order if dmi(k)), "") or dmi("board_name")
    if not name:
        return None
    if vendor and vendor.lower().split()[0] not in name.lower():
        name = f"{vendor} {name}"
    return name


def distro():
    d = {}
    for line in (read("/etc/os-release") or "").splitlines():
        k, _, v = line.partition("=")
        d[k] = v.strip('"')
    return d.get("PRETTY_NAME") or d.get("NAME") or "Linux", d.get("ID", "")


def cpu_info():
    model, cores, threads, phys = None, set(), 0, None
    for line in (read("/proc/cpuinfo") or "").splitlines():
        k, _, v = line.partition(":")
        k, v = k.strip(), v.strip()
        if k == "processor":
            threads += 1
        elif k == "model name" and model is None:
            model = v
        elif k == "physical id":
            phys = v
        elif k == "core id":
            cores.add((phys, v))
    base = None
    m = re.search(r"@\s*([\d.]+)\s*GHz", model or "")
    if m:
        base = float(m.group(1))
    if model:
        model = re.sub(r"\((?:R|TM)\)|\bCPU\b|\bProcessor\b|@.*$| w/ .*$| with .*$", "", model)
        model = " ".join(model.split())
    return model, len(cores) or threads, threads, base


VENDORS = {"Advanced Micro Devices, Inc. [AMD/ATI]": "AMD", "Advanced Micro Devices, Inc.": "AMD",
           "Intel Corporation": "Intel", "NVIDIA Corporation": "NVIDIA"}


def gpu_models():
    names = []
    if not shutil.which("lspci"):
        return names
    for line in run(["lspci", "-mm"], timeout=3).splitlines():
        try:
            f = shlex.split(line)
        except ValueError:
            continue
        if len(f) >= 4 and re.search(r"VGA|3D|Display", f[1]):
            vendor = VENDORS.get(f[2], re.sub(r",? ?(Inc\.?|Corporation|Co\., Ltd\.)", "", f[2]).strip())
            m = re.search(r"\[(.+)\]", f[3])
            names.append(f"{vendor} {m.group(1) if m else f[3]}")
    return names


def disk_models():
    out = []
    for dev in sorted(glob.glob("/sys/block/*")):
        name = os.path.basename(dev)
        if name.startswith(("loop", "ram", "zram", "dm-", "sr", "md")) or read(dev + "/removable") == "1":
            continue
        model = read(dev + "/device/model")
        sectors = num(dev + "/size")
        if model and sectors:
            b = sectors * 512
            cap = f"{b / 1e12:.1f} TB" if b >= 1e12 else f"{b / 1e9:.0f} GB"
            out.append(f"{' '.join(model.split())} · {cap}")
    return out


def hypr_version():
    if not shutil.which("hyprctl"):
        return None
    try:
        v = json.loads(run(["hyprctl", "version", "-j"]))
        return v.get("tag") or v.get("version")
    except ValueError:
        return None


_displays = (-1e9, [])


def displays():
    global _displays
    if time.monotonic() - _displays[0] > 30:
        out = []
        if shutil.which("hyprctl"):
            try:
                for m in json.loads(run(["hyprctl", "monitors", "-j"])):
                    out.append(f"{m['name']} {m['width']}×{m['height']}@{m['refreshRate']:.0f}Hz")
            except (ValueError, KeyError):
                pass
        _displays = (time.monotonic(), out)
    return _displays[1]


DISTRO_NAME, DISTRO_ID = distro()
UNAME = os.uname()
HOST = host_model()
CPU_MODEL, CPU_CORES, CPU_THREADS, CPU_BASE_NAME = cpu_info()
GPUS = gpu_models()
DISKS_HW = disk_models()
HYPR = hypr_version()


def parse_cpulist(text):
    out = set()
    for part in (text or "").split(","):
        a, _, b = part.strip().partition("-")
        try:
            out.update(range(int(a), int(b or a) + 1))
        except ValueError:
            pass
    return out


def khz_range(name):
    """(max, min) over all cores of a cpufreq attribute, in GHz."""
    vals = [num(p) for p in glob.glob(f"/sys/devices/system/cpu/cpu[0-9]*/cpufreq/{name}")]
    vals = [v for v in vals if v]
    return (max(vals) / 1e6, min(vals) / 1e6) if vals else (None, None)


def cache_size(text):
    m = re.match(r"(\d+)([KMG])", text or "")
    if not m:
        return text
    k = int(m.group(1)) * {"K": 1, "M": 1024, "G": 1048576}[m.group(2)]
    return f"{k} KiB" if k < 1024 else f"{k / 1024:g} MiB"


def cache_info():
    out = []
    for d in sorted(glob.glob("/sys/devices/system/cpu/cpu0/cache/index[0-9]*")):
        level, ctype, sz = read(d + "/level"), read(d + "/type"), read(d + "/size")
        if not (level and sz) or ctype == "Instruction":
            continue
        out.append(f"L{level}{'d' if level == '1' else ''} {cache_size(sz)}")
    return out


def thread_groups():
    """Logical CPUs grouped by physical core (SMT siblings together)."""
    groups = set()
    for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*"):
        i = int(os.path.basename(p)[3:])
        groups.add(tuple(sorted(parse_cpulist(read(p + "/topology/thread_siblings_list")) or {i})))
    return sorted(groups)


def hybrid_classes():
    """Intel hybrid: [(label, {cpus})] for P / E / LP-E cores, else []."""
    classes = []
    for label, path in (("P", "/sys/devices/cpu_core/cpus"), ("E", "/sys/devices/cpu_atom/cpus"),
                        ("LP", "/sys/devices/cpu_lowpower/cpus")):
        cpus = parse_cpulist(read(path))
        if cpus:
            classes.append((label, cpus))
    return classes if len(classes) > 1 else []


CPU_BASE = khz_range("base_frequency")[0] or CPU_BASE_NAME
CPU_BOOST, CPU_MIN = khz_range("cpuinfo_max_freq")[0], khz_range("cpuinfo_min_freq")[1]
CPU_CACHE = cache_info()
GROUPS = thread_groups()
HYBRID = hybrid_classes()


def cpu_policy():
    """Governor, driver, turbo and EPP: these change with the power profile."""
    d = "/sys/devices/system/cpu/cpu0/cpufreq/"
    parts = [x for x in (read(d + "scaling_governor"), read(d + "scaling_driver")) if x]
    turbo = None
    if os.path.exists("/sys/devices/system/cpu/intel_pstate/no_turbo"):
        turbo = read("/sys/devices/system/cpu/intel_pstate/no_turbo") == "0"
    elif os.path.exists("/sys/devices/system/cpu/cpufreq/boost"):
        turbo = read("/sys/devices/system/cpu/cpufreq/boost") == "1"
    if turbo is not None:
        parts.append("Turbo " + ("on" if turbo else "off"))
    epp = read(d + "energy_performance_preference")
    if epp:
        parts.append(f"EPP {epp}")
    return parts


def system_block():
    rows = []
    if HOST:
        rows.append(info_row("Host", HOST))
    rows.append(info_row("Kernel", UNAME.release))
    rows += [info_row("GPU", g) for g in GPUS]
    rows += [info_row("Disk", d) for d in DISKS_HW]
    rows += [info_row("Display", d) for d in displays()]
    if HYPR:
        rows.append(info_row("WM", f"Hyprland {HYPR}"))
    rows.append(info_row("Uptime", uptime()))
    icon = DISTRO_ICONS.get(DISTRO_ID, GENERIC_ICON)
    return f"<b>{icon}  {esc(DISTRO_NAME)}</b>  {dim(esc(UNAME.machine))}\n" + "\n".join(rows)


# ── CPU ──────────────────────────────────────────────────────────────────────

def cpu_times():
    """-> ((idle, total) overall, {core label: (idle, total)})"""
    overall, cores = (0, 0), {}
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        f = line.split()
        v = [int(x) for x in f[1:9]]
        entry = (v[3] + v[4], sum(v))  # idle(+iowait), total
        if f[0] == "cpu":
            overall = entry
        else:
            cores[f[0][3:]] = entry
    return overall, cores


def usage(prev, cur):
    dt = cur[1] - prev[1]
    return 100 * (1 - (cur[0] - prev[0]) / dt) if dt > 0 else 0.0


def cpu_freq():
    f = [num(p) for p in glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq")]
    f = [x for x in f if x]
    return (sum(f) / len(f) / 1e6, max(f) / 1e6) if f else (None, None)  # kHz -> GHz


def level_chars(p):
    """Two-row bar: 16 height levels (upper glyph, lower glyph)."""
    lvl = round(p / 100 * 16)
    return (SPARK[lvl - 9] if lvl > 8 else " "), SPARK[max(min(lvl, 8), 1) - 1]


def core_chart(pcts):
    """pcts: {cpu: percent}. One two-row bar per thread, SMT siblings touching,
    cores separated by a space. Intel hybrid CPUs get P / E / LP rows."""
    def rows(groups, label):
        tops, bots = [], []
        for g in groups:
            pairs = [level_chars(pcts[c]) for c in g if c in pcts]
            if pairs:
                tops.append("".join(t for t, _ in pairs))
                bots.append("".join(b for _, b in pairs))
        if not bots:
            return []
        pad = f"{label:<3}" if label else ""
        wrap = lambda t: f"<span font_family='{GRID_FONT}'>{t}</span>"
        return ["    " + wrap(" " * len(pad) + " ".join(tops)), "    " + wrap(pad + " ".join(bots))]

    if HYBRID:
        out = []
        for label, cpus in HYBRID:
            out += rows([g for g in GROUPS if g[0] in cpus], label)
        return "\n".join(out)
    return "\n".join(rows(GROUPS, ""))


# ── processes ────────────────────────────────────────────────────────────────

def proc_snapshot():
    snap = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as f:
                s = f.read()
        except OSError:
            continue
        i, j = s.find("("), s.rfind(")")
        rest = s[j + 2:].split()
        snap[pid] = (s[i + 1:j], int(rest[11]) + int(rest[12]))  # comm, utime+stime
    return snap


def top_procs(prev, cur, dt):
    """Group by process name: [(name, cpu% of one core, rss bytes, count)]"""
    groups = {}
    for pid, (comm, ticks) in cur.items():
        if pid in prev:
            c = (ticks - prev[pid][1]) / CLK / dt * 100
            if c > 0.1:
                g = groups.setdefault(comm, [0.0, []])
                g[0] += c
                g[1].append(pid)
    out = []
    for comm, (c, pids) in sorted(groups.items(), key=lambda kv: -kv[1][0])[:TOP_PROCS]:
        rss = 0
        for pid in pids:
            try:
                rss += int(read(f"/proc/{pid}/statm", "0 0").split()[1]) * PAGE
            except (ValueError, IndexError):
                pass
        out.append((comm, c, rss, len(pids)))
    return out


# ── memory / disk ────────────────────────────────────────────────────────────

def meminfo():
    d = {}
    for line in read("/proc/meminfo").splitlines():
        k, v = line.split(":")
        d[k] = int(v.split()[0])  # kiB
    total, used = d["MemTotal"], d["MemTotal"] - d["MemAvailable"]
    swap_t = d.get("SwapTotal", 0)
    return total, used, swap_t, swap_t - d.get("SwapFree", 0)


REAL_FS = {"ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "zfs", "ntfs", "ntfs3", "exfat", "vfat", "fuseblk"}


def disks():
    seen = {}
    for line in (read("/proc/mounts") or "").splitlines():
        dev, mnt, fs = line.split()[:3]
        mnt = mnt.replace("\\040", " ")
        if fs not in REAL_FS or mnt.startswith(("/boot", "/efi")):
            continue
        if dev not in seen or len(mnt) < len(seen[dev]):
            seen[dev] = mnt  # btrfs subvolumes share a device: keep the shortest mount
    out = []
    for mnt in sorted(seen.values(), key=len)[:MAX_DISKS]:
        try:
            s = os.statvfs(mnt)
        except OSError:
            continue
        total = s.f_blocks * s.f_frsize
        used = total - s.f_bfree * s.f_frsize
        avail = s.f_bavail * s.f_frsize
        out.append((mnt, used, total, used / (used + avail) * 100 if used + avail else 0))
    return out


# ── energy ───────────────────────────────────────────────────────────────────

def battery():
    base = next(iter(sorted(glob.glob("/sys/class/power_supply/BAT*"))), None)
    if not base:
        return None
    volt = num(base + "/voltage_now")

    def energy(name):  # µWh, from energy_* or charge_* * voltage
        v = num(f"{base}/energy_{name}")
        if v is None:
            c = num(f"{base}/charge_{name}")
            v = c * volt / 1e6 if c is not None and volt else None
        return v

    watts = num(base + "/power_now")
    watts = watts / 1e6 if watts is not None else None
    if watts is None:
        cur = num(base + "/current_now")
        watts = cur * volt / 1e12 if cur is not None and volt else None

    status = read(base + "/status", "Unknown")
    now, full, design = energy("now"), energy("full"), energy("full_design")
    hours = None
    if watts and watts > 0.1 and now is not None and full is not None:
        if status == "Discharging":
            hours = now / (watts * 1e6)
        elif status == "Charging":
            hours = (full - now) / (watts * 1e6)
    model = " ".join(filter(None, (read(base + "/manufacturer"), read(base + "/model_name"))))
    return {
        "cap": num(base + "/capacity"),
        "status": status,
        "watts": watts,
        "hours": hours,
        "health": full / design * 100 if full and design else None,
        "model": model,
    }


_profile = (-1e9, None)


def power_profile():
    global _profile
    if time.monotonic() - _profile[0] > 10:
        out = None
        if shutil.which("powerprofilesctl"):
            out = run(["powerprofilesctl", "get"]).strip() or None
        _profile = (time.monotonic(), out)
    return _profile[1]


# ── thermal ──────────────────────────────────────────────────────────────────

def hwmon_by_name(*names):
    return [p for p in sorted(glob.glob("/sys/class/hwmon/hwmon*")) if read(p + "/name") in names]


def find_cpu_temp():
    for p in hwmon_by_name("coretemp", "k10temp", "zenpower", "cpu_thermal", "acpitz"):
        for lab in sorted(glob.glob(p + "/temp*_label")):
            if read(lab) in ("Package id 0", "Tctl", "Tdie"):
                return lab.replace("_label", "_input")
        if os.path.exists(p + "/temp1_input"):
            return p + "/temp1_input"
    z = "/sys/class/thermal/thermal_zone0/temp"
    return z if os.path.exists(z) else None


CPU_TEMP = find_cpu_temp()
NVME_TEMPS = [p + "/temp1_input" for p in hwmon_by_name("nvme")]
FANS = sorted(glob.glob("/sys/class/hwmon/hwmon*/fan*_input"))


def celsius(path):
    t = num(path) if path else None
    return t / 1000 if t is not None else None


def gpu():
    if not SHOW_GPU:
        return None
    for base in glob.glob("/sys/class/drm/card[0-9]/device"):
        busy = num(base + "/gpu_busy_percent")
        if busy is not None:
            temps = glob.glob(base + "/hwmon/hwmon*/temp1_input")
            return busy, celsius(temps[0]) if temps else None
    if shutil.which("nvidia-smi"):
        out = run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu",
                   "--format=csv,noheader,nounits"], timeout=3)
        try:
            util, temp = (float(x) for x in out.split(","))
            return util, temp
        except ValueError:
            pass
    return None


# ── main loop ────────────────────────────────────────────────────────────────

def main():
    prev_all, prev_cores = cpu_times()
    prev_t = time.monotonic()
    prev_procs = proc_snapshot() if TOP_PROCS else {}
    delay = 0.5

    while True:
        time.sleep(delay)
        delay = INTERVAL
        now_t = time.monotonic()
        dt = max(now_t - prev_t, 0.001)
        prev_t = now_t

        # CPU
        cur_all, cur_cores = cpu_times()
        cpu = usage(prev_all, cur_all)
        core_pcts = [(k, usage(prev_cores[k], v)) for k, v in cur_cores.items() if k in prev_cores]
        prev_all, prev_cores = cur_all, cur_cores
        freq, freq_peak = cpu_freq()
        load = os.getloadavg()
        temp = celsius(CPU_TEMP)

        # memory
        mem_t, mem_u, swap_t, swap_u = meminfo()
        mem_pct = mem_u / mem_t * 100

        # processes
        top = []
        if TOP_PROCS:
            cur_procs = proc_snapshot()
            top = top_procs(prev_procs, cur_procs, dt)
            prev_procs = cur_procs

        lines = [system_block()]

        # CPU block
        cpu_block = f"<b>{CPU}  CPU</b>  {cpu:.0f}%  {bar(cpu)}"
        model = [esc(CPU_MODEL)] if CPU_MODEL else []
        if CPU_CORES:
            model.append(f"{CPU_CORES}C/{CPU_THREADS}T")
        clocks = []
        if CPU_BASE:
            clocks.append(f"Base {CPU_BASE:.2f} GHz")
        if CPU_BOOST:
            clocks.append(f"Boost {CPU_BOOST:.2f} GHz")
        if CPU_MIN and not CPU_BASE:
            clocks.append(f"Min {CPU_MIN:.2f} GHz")
        if freq:
            clocks.append(f"Now {freq:.2f} GHz" + (f" (peak {freq_peak:.2f})" if freq_peak else ""))
        details = [model, clocks, cpu_policy(), CPU_CACHE,
                   ["Load " + " ".join(f"{x:.2f}" for x in load)]]
        for d in details:
            if d:
                cpu_block += "\n    " + dim(" · ".join(d))
        pcts = {int(k): p for k, p in core_pcts}
        if pcts:
            cpu_block += "\n\n" + core_chart(pcts)
            busy = [f"cpu{c} {p:.0f}%" for c, p in sorted(pcts.items(), key=lambda kv: -kv[1])[:3] if p >= 5]
            cpu_block += "\n" + info_row("Busiest", " · ".join(busy) if busy else "all cores idle")
        lines.append(cpu_block)

        # memory block
        lines.append(
            f"<b>{MEM}  Memory</b>  {mem_pct:.0f}%  {bar(mem_pct)}\n    "
            + dim(f"{size(mem_u * 1024)} / {size(mem_t * 1024)}"
                  + (f" · Swap {size(swap_u * 1024)} / {size(swap_t * 1024)}" if swap_t else "")))

        # disk block
        ds = disks()
        if ds:
            lines.append(f"<b>{DISK}  Disk</b>\n" + "\n".join(
                f"    {esc(m)}  " + dim(f"{size(u)} / {size(t)}") + f"  {p:.0f}%  {bar(p)}"
                for m, u, t, p in ds))

        # energy block
        bat = battery()
        if bat and bat["cap"] is not None:
            row = [bat["status"]]
            if bat["watts"] is not None:
                row.append(f"{bat['watts']:.1f} W")
            if bat["hours"]:
                row.append(f"{hm(bat['hours'])} " + ("left" if bat["status"] == "Discharging" else "to full"))
            extra = []
            if bat["health"]:
                extra.append(f"Health {bat['health']:.0f}%")
            if power_profile():
                extra.append(f"Profile {esc(power_profile())}")
            block = f"<b>{POWER}  Energy</b>  {bat['cap']:.0f}%  {bar(bat['cap'])}\n    " + " · ".join(row)
            if extra:
                block += "\n    " + dim(" · ".join(extra))
            if bat["model"]:
                block += "\n    " + dim(esc(bat["model"]))
            lines.append(block)

        # thermal block
        therm = []
        if temp is not None:
            therm.append(f"CPU {temp:.0f}°C")
        for p in NVME_TEMPS:
            t = celsius(p)
            if t is not None:
                therm.append(f"NVMe {t:.0f}°C")
        g = gpu()
        if g and g[1] is not None:
            therm.append(f"GPU {g[1]:.0f}°C")
        rpm = [r for r in (num(p) for p in FANS) if r is not None]
        if rpm:
            therm.append(f"Fan {max(rpm):.0f} rpm")
        if therm:
            lines.append(f"<b>{TEMP}  Thermal</b>\n    " + " · ".join(therm))

        if g:
            lines.append(f"<b>GPU</b>  {g[0]:.0f}%  {bar(g[0])}")

        # top processes
        if top:
            rows = []
            for name, c, rss, n in top:
                label = esc(name) + (f" ×{n}" if n > 1 else "")
                rows.append(f"    {label}  {c:.0f}%  " + dim(size(rss)))
            lines.append(f"<b>{TOP}  Top processes</b>\n" + "\n".join(rows))

        # state colour on the pill
        cls = ""
        if cpu >= 85 or mem_pct >= 85 or (temp is not None and temp >= 80):
            cls = "warning"
        if mem_pct >= 95 or (temp is not None and temp >= 90):
            cls = "critical"

        try:
            print(json.dumps({
                "text": f"{CPU}  {cpu:.0f}% | {MEM}  {mem_pct:.0f}%",
                "tooltip": "\n\n".join(lines),
                "class": cls,
            }), flush=True)
        except BrokenPipeError:
            sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
