#!/usr/bin/env python3
import os
import sys
import json
import glob
import re
import struct
import subprocess

def parse_edid_max_hz(edid_bytes, target_w=None, target_h=None):
    max_hz = 60
    if len(edid_bytes) < 128:
        return max_hz

    # Check header
    if edid_bytes[:8] != b'\x00\xff\xff\xff\xff\xff\xff\x00':
        return max_hz

    # Standard Timings: bytes 38-53 (8 timing pairs)
    for i in range(38, 54, 2):
        b1, b2 = edid_bytes[i], edid_bytes[i+1]
        if b1 != 1 or b2 != 1:
            hz = (b2 & 0x3f) + 60
            if hz > max_hz and hz <= 360:
                max_hz = hz

    def parse_dtd(block):
        if len(block) < 18:
            return None
        pixel_clock = (block[0] | (block[1] << 8)) * 10000
        if pixel_clock == 0:
            return None
        h_active = block[2] | ((block[4] & 0xf0) << 4)
        h_blank = block[3] | ((block[4] & 0x0f) << 8)
        v_active = block[5] | ((block[7] & 0xf0) << 4)
        v_blank = block[6] | ((block[7] & 0x0f) << 8)
        h_total = h_active + h_blank
        v_total = v_active + v_blank
        if h_total > 0 and v_total > 0:
            hz = pixel_clock / (h_total * v_total)
            return (h_active, v_active, round(hz))
        return None

    # Base Detailed Timing Descriptors (bytes 54-125: 4 descriptors)
    for i in range(54, 126, 18):
        res = parse_dtd(edid_bytes[i:i+18])
        if res:
            w, h, hz = res
            if hz > max_hz and hz <= 500:
                if target_w and target_h:
                    if w == target_w and h == target_h:
                        max_hz = hz
                else:
                    max_hz = hz

    # Extension Blocks (CEA/CTA-861 often contains 120Hz/144Hz/240Hz timings)
    num_ext = edid_bytes[126] if len(edid_bytes) > 126 else 0
    for ext_idx in range(num_ext):
        ext_offset = 128 * (ext_idx + 1)
        if len(edid_bytes) < ext_offset + 128:
            break
        ext = edid_bytes[ext_offset:ext_offset + 128]
        if ext[0] == 0x02:
            dtd_start = ext[2]
            if 4 <= dtd_start <= 127:
                for pos in range(dtd_start, 127 - 17, 18):
                    res = parse_dtd(ext[pos:pos+18])
                    if res:
                        w, h, hz = res
                        if hz > max_hz and hz <= 500:
                            if target_w and target_h:
                                if w == target_w and h == target_h:
                                    max_hz = hz
                            else:
                                max_hz = hz

    return max_hz

def get_hz_from_edid_file(edid_path, target_w=None, target_h=None):
    try:
        proc = subprocess.run(["edid-decode", edid_path], capture_output=True, text=True, timeout=3)
        if proc.returncode == 0 and proc.stdout:
            max_hz = 60
            for line in proc.stdout.splitlines():
                m = re.search(r'(\d+)x(\d+)[\s@]+([0-9.]+)\s*Hz', line)
                if m:
                    w, h, hz = int(m.group(1)), int(m.group(2)), round(float(m.group(3)))
                    if hz > max_hz and hz <= 500:
                        if target_w and target_h:
                            if w == target_w and h == target_h:
                                max_hz = hz
                        else:
                            max_hz = hz
            if max_hz > 60:
                return max_hz
    except Exception:
        pass

    try:
        with open(edid_path, "rb") as f:
            data = f.read()
        return parse_edid_max_hz(data, target_w, target_h)
    except Exception:
        return 60

def detect_monitors():
    # 1. Hyprland
    try:
        proc = subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True, text=True, timeout=3)
        if proc.returncode != 0 or not proc.stdout.strip():
            proc = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=3)
        if proc.returncode == 0 and proc.stdout.strip():
            data = json.loads(proc.stdout)
            if isinstance(data, list) and len(data) > 0:
                result = []
                for item in data:
                    name = item.get("name", "")
                    if not name:
                        continue
                    w = int(item.get("width", 1920))
                    h = int(item.get("height", 1080))
                    curr_rr = round(float(item.get("refreshRate", 60)))
                    max_hz = curr_rr
                    modes = item.get("availableModes", [])
                    for m_str in modes:
                        m = re.match(r"^(\d+)x(\d+)@([0-9.]+)", m_str.strip())
                        if m:
                            mw, mh, mhz = int(m.group(1)), int(m.group(2)), round(float(m.group(3)))
                            if mw == w and mh == h:
                                if mhz > max_hz:
                                    max_hz = mhz
                    result.append({"name": name, "width": w, "height": h, "max_hz": max_hz, "compositor": "hyprland"})
                if result:
                    return result
    except Exception:
        pass

    # 2. Sway
    try:
        proc = subprocess.run(["swaymsg", "-t", "get_outputs", "-r"], capture_output=True, text=True, timeout=3)
        if proc.returncode == 0 and proc.stdout.strip():
            data = json.loads(proc.stdout)
            if isinstance(data, list) and len(data) > 0:
                result = []
                for item in data:
                    name = item.get("name", "")
                    if not name:
                        continue
                    modes = item.get("modes", [])
                    if modes:
                        best_mode = max(modes, key=lambda m: (m.get("width", 0) * m.get("height", 0), m.get("refresh", 0)))
                        w = best_mode.get("width", 1920)
                        h = best_mode.get("height", 1080)
                        same_res_modes = [m for m in modes if m.get("width") == w and m.get("height") == h]
                        max_hz = round(max([m.get("refresh", 60000) for m in same_res_modes]) / 1000.0)
                    else:
                        rect = item.get("rect", {})
                        w = rect.get("width", 1920)
                        h = rect.get("height", 1080)
                        max_hz = 60
                    result.append({"name": name, "width": w, "height": h, "max_hz": max_hz, "compositor": "sway"})
                if result:
                    return result
    except Exception:
        pass

    # 3. Niri
    try:
        proc = subprocess.run(["niri", "msg", "-j", "outputs"], capture_output=True, text=True, timeout=3)
        if proc.returncode == 0 and proc.stdout.strip():
            data = json.loads(proc.stdout)
            result = []
            for k, item in data.items():
                name = item.get("name", k)
                modes = item.get("modes", [])
                if modes:
                    best_mode = max(modes, key=lambda m: (m.get("width", 0) * m.get("height", 0), m.get("refresh_rate", 0)))
                    w = best_mode.get("width", 1920)
                    h = best_mode.get("height", 1080)
                    same_res_modes = [m for m in modes if m.get("width") == w and m.get("height") == h]
                    max_hz = round(max([m.get("refresh_rate", 60000) for m in same_res_modes]) / 1000.0)
                else:
                    w, h, max_hz = 1920, 1080, 60
                result.append({"name": name, "width": w, "height": h, "max_hz": max_hz, "compositor": "niri"})
            if result:
                return result
    except Exception:
        pass

    # 4. wlr-randr
    try:
        proc = subprocess.run(["wlr-randr"], capture_output=True, text=True, timeout=3)
        if proc.returncode == 0 and proc.stdout.strip():
            result = []
            curr_name = ""
            curr_modes = []
            for line in proc.stdout.splitlines():
                if line and not line.startswith(" "):
                    if curr_name and curr_modes:
                        w, h = curr_modes[0][0], curr_modes[0][1]
                        same_res = [m for m in curr_modes if m[0] == w and m[1] == h]
                        max_hz = max([m[2] for m in same_res])
                        result.append({"name": curr_name, "width": w, "height": h, "max_hz": max_hz, "compositor": "wlroots"})
                    curr_name = line.split()[0]
                    curr_modes = []
                elif "px," in line and "Hz" in line:
                    m = re.search(r"(\d+)x(\d+)\s+px,\s+([0-9.]+)\s+Hz", line)
                    if m:
                        curr_modes.append((int(m.group(1)), int(m.group(2)), round(float(m.group(3)))))
            if curr_name and curr_modes:
                w, h = curr_modes[0][0], curr_modes[0][1]
                same_res = [m for m in curr_modes if m[0] == w and m[1] == h]
                max_hz = max([m[2] for m in same_res])
                result.append({"name": curr_name, "width": w, "height": h, "max_hz": max_hz, "compositor": "wlroots"})
            if result:
                return result
    except Exception:
        pass

    # 5. Linux DRM /sys/class/drm/ (fallback when no display server is running)
    try:
        drm_monitors = []
        for sf in glob.glob("/sys/class/drm/card*-*/status"):
            try:
                with open(sf, "r") as f:
                    if f.read().strip() != "connected":
                        continue
                port_dir = os.path.dirname(sf)
                port_name = os.path.basename(port_dir)
                mon_name = re.sub(r"^card\d+-", "", port_name)

                modes_file = os.path.join(port_dir, "modes")
                w, h = 1920, 1080
                if os.path.exists(modes_file):
                    with open(modes_file, "r") as mf:
                        for l in mf:
                            m = re.match(r"^(\d+)x(\d+)", l.strip())
                            if m:
                                w, h = int(m.group(1)), int(m.group(2))
                                break

                edid_file = os.path.join(port_dir, "edid")
                max_hz = 60
                if os.path.exists(edid_file) and os.path.getsize(edid_file) > 0:
                    max_hz = get_hz_from_edid_file(edid_file, w, h)

                drm_monitors.append({"name": mon_name, "width": w, "height": h, "max_hz": max_hz, "compositor": "drm"})
            except Exception:
                continue
        if drm_monitors:
            return drm_monitors
    except Exception:
        pass

    return []

def apply_monitors(monitors):
    if not monitors:
        return

    home = os.path.expanduser("~")

    # 1. Configure Hyprland (~/.config/hypr/config/monitors.lua)
    hypr_mon_dir = os.path.join(home, ".config/hypr/config")
    os.makedirs(hypr_mon_dir, exist_ok=True)
    hypr_mon_file = os.path.join(hypr_mon_dir, "monitors.lua")

    lua_lines = [
        "-- Auto-configured by Atlantic on install",
        "-- Highest refresh rate (Hz) detected for connected monitor(s)",
    ]
    for mon in monitors:
        name = mon["name"]
        w = mon["width"]
        h = mon["height"]
        hz = mon["max_hz"]
        lua_lines.append(f'hl.monitor({{\n  output = "{name}",\n  mode = "{w}x{h}@{hz}",\n  position = "auto",\n  scale = 1.0,\n}})')
        try:
            subprocess.run(["hyprctl", "keyword", "monitor", f"{name},{w}x{h}@{hz},auto,1"], capture_output=True, timeout=2)
        except Exception:
            pass

    lua_lines.append('-- Fallback rule for any newly connected displays\nhl.monitor({\n  output = "",\n  mode = "highrr",\n  position = "auto",\n  scale = 1.0,\n})\n')

    with open(hypr_mon_file, "w") as f:
        f.write("\n".join(lua_lines))

    # 2. Configure Sway (~/.config/sway/configDir/output)
    sway_out_dir = os.path.join(home, ".config/sway/configDir")
    os.makedirs(sway_out_dir, exist_ok=True)
    sway_out_file = os.path.join(sway_out_dir, "output")
    sway_lines = ["# Auto-configured by Atlantic on install"]
    for mon in monitors:
        name = mon["name"]
        w = mon["width"]
        h = mon["height"]
        hz = mon["max_hz"]
        sway_lines.append(f'output "{name}" {{\n    mode {w}x{h}@{hz}Hz\n    position 0 0\n    scale 1.0\n}}')
        try:
            subprocess.run(["swaymsg", "output", name, "mode", f"{w}x{h}@{hz}Hz"], capture_output=True, timeout=2)
        except Exception:
            pass
    sway_lines.append("output * {\n    resolution preferred\n    position 0 0\n    scale 1.0\n}\n")
    with open(sway_out_file, "w") as f:
        f.write("\n".join(sway_lines))

    # 3. Configure Niri (~/.config/niri/config/output.kdl)
    niri_out_dir = os.path.join(home, ".config/niri/config")
    os.makedirs(niri_out_dir, exist_ok=True)
    niri_out_file = os.path.join(niri_out_dir, "output.kdl")
    niri_lines = ["// Auto-configured by Atlantic on install"]
    for mon in monitors:
        name = mon["name"]
        w = mon["width"]
        h = mon["height"]
        hz = mon["max_hz"]
        niri_lines.append(f'output "{name}" {{\n    mode "{w}x{h}@{hz}"\n    scale 1.0\n}}')
        try:
            subprocess.run(["niri", "msg", "output", name, "mode", f"{w}x{h}@{hz}"], capture_output=True, timeout=2)
        except Exception:
            pass
    with open(niri_out_file, "w") as f:
        f.write("\n".join(niri_lines))

    # 4. Update ~/.config/atlantic/settings.json
    cfg_file = os.path.join(home, ".config/atlantic/settings.json")
    try:
        cfg = {}
        if os.path.exists(cfg_file):
            with open(cfg_file, "r") as f:
                cfg = json.load(f)
        if "display" not in cfg:
            cfg["display"] = {}
        if "monitors" not in cfg["display"]:
            cfg["display"]["monitors"] = {}

        for mon in monitors:
            name = mon["name"]
            cfg["display"]["monitors"][name] = {
                "enabled": False,
                "scale": 1,
                "dimensions": f"{mon['width']}x{mon['height']}",
                "framerate": str(mon["max_hz"])
            }
        with open(cfg_file, "w") as f:
            json.dump(cfg, f, indent=2)
    except Exception:
        pass

    # Reset any active blue light / night light filter to neutral 6500K sRGB
    try:
        subprocess.run(["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", "6500"], capture_output=True, timeout=2)
        subprocess.run(["pkill", "-9", "-x", "wl-gammarelay-rs"], capture_output=True, timeout=2)
    except Exception:
        pass

def apply_mouse_dpi(target_dpi=1600):
    # 1. libratbag / ratbagctl (Logitech, SteelSeries, Roccat, etc.)
    try:
        subprocess.run(["systemctl", "--user", "start", "ratbagd.service"], capture_output=True, timeout=3)
    except Exception:
        pass

    try:
        res = subprocess.run(["ratbagctl", "list"], capture_output=True, text=True, timeout=4)
        if res.returncode == 0 and res.stdout.strip():
            for line in res.stdout.strip().splitlines():
                if ":" in line:
                    dev_id = line.split(":", 1)[0].strip()
                    subprocess.run(["ratbagctl", dev_id, "dpi", "set", str(target_dpi)], capture_output=True, timeout=3)
    except Exception:
        pass

    # 2. Razer devices
    try:
        subprocess.run(["razer-cli", "-d", str(target_dpi)], capture_output=True, timeout=3)
    except Exception:
        pass

    # 3. udev hwdb rule for default 1600 DPI
    hwdb_content = f"""# Atlantic auto-configured mouse DPI
mouse:*:*
 MOUSE_DPI={target_dpi}@1000
"""
    hwdb_file = "/etc/udev/hwdb.d/71-mouse-local.hwdb"
    try:
        if os.geteuid() == 0:
            os.makedirs(os.path.dirname(hwdb_file), exist_ok=True)
            with open(hwdb_file, "w") as f:
                f.write(hwdb_content)
            subprocess.run(["systemd-hwdb", "update"], capture_output=True, timeout=5)
            subprocess.run(["udevadm", "trigger", "/dev/input/event*"], capture_output=True, timeout=5)
        elif subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0:
            p = subprocess.Popen(["sudo", "tee", hwdb_file], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            p.communicate(input=hwdb_content.encode())
            subprocess.run(["sudo", "systemd-hwdb", "update"], capture_output=True, timeout=5)
            subprocess.run(["sudo", "udevadm", "trigger", "/dev/input/event*"], capture_output=True, timeout=5)
    except Exception:
        pass

    # 4. Save to ~/.config/atlantic/settings.json
    cfg_file = os.path.expanduser("~/.config/atlantic/settings.json")
    try:
        if os.path.exists(cfg_file):
            with open(cfg_file, "r") as f:
                cfg = json.load(f)
            if "mouse" not in cfg:
                cfg["mouse"] = {}
            cfg["mouse"]["dpi"] = target_dpi
            with open(cfg_file, "w") as f:
                json.dump(cfg, f, indent=2)
    except Exception:
        pass

def fix_steam_loopback():
    hosts_file = "/etc/hosts"
    nsswitch_file = "/etc/nsswitch.conf"
    try:
        if os.path.exists(hosts_file):
            with open(hosts_file, "r") as f:
                content = f.read()
            if "steamloopback.host" not in content:
                addition = "\n127.0.0.1 steamloopback.host\n::1 steamloopback.host\n"
                if os.geteuid() == 0:
                    with open(hosts_file, "a") as f:
                        f.write(addition)
                elif subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0:
                    p = subprocess.Popen(["sudo", "tee", "-a", hosts_file], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    p.communicate(input=addition.encode())
    except Exception:
        pass

    try:
        if os.path.exists(nsswitch_file):
            with open(nsswitch_file, "r") as f:
                lines = f.readlines()
            new_lines = []
            modified = False
            for line in lines:
                if line.strip().startswith("hosts:"):
                    parts = line.strip().split()
                    entries = [p for p in parts[1:] if p != "files"]
                    new_line = "hosts: files " + " ".join(entries) + "\n"
                    if new_line != line:
                        new_lines.append(new_line)
                        modified = True
                    else:
                        new_lines.append(line)
                else:
                    new_lines.append(line)
            if modified:
                new_content = "".join(new_lines)
                if os.geteuid() == 0:
                    with open(nsswitch_file, "w") as f:
                        f.write(new_content)
                elif subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0:
                    p = subprocess.Popen(["sudo", "tee", nsswitch_file], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    p.communicate(input=new_content.encode())
    except Exception:
        pass

def fix_steam_config():
    import shutil
    home = os.path.expanduser("~")
    steam_data = os.path.join(home, ".local/share/Steam")
    steam_link_dir = os.path.join(home, ".steam")
    steam_link = os.path.join(steam_link_dir, "steam")
    steam_root = os.path.join(steam_link_dir, "root")
    cfg_content = "@nClientDownloadEnableHTTP2PlatformLinux 0\n@fDownloadRateImprovementToAddAnotherConnection 1.0\n"

    try:
        os.makedirs(steam_data, exist_ok=True)
        os.makedirs(steam_link_dir, exist_ok=True)

        # Fix "Couldn't set up Steam data":
        # ~/.steam/steam and ~/.steam/root MUST be symlinks, NEVER directories!
        for lpath in [steam_link, steam_root]:
            if os.path.exists(lpath) and not os.path.islink(lpath):
                try:
                    for item in os.listdir(lpath):
                        s = os.path.join(lpath, item)
                        d = os.path.join(steam_data, item)
                        if not os.path.exists(d):
                            shutil.move(s, d)
                except Exception:
                    pass
                shutil.rmtree(lpath, ignore_errors=True)
            if not os.path.exists(lpath) and not os.path.islink(lpath):
                try:
                    os.symlink(steam_data, lpath)
                except Exception:
                    pass

        # Write steam_dev.cfg to disable HTTP/2 throttling on Linux
        fpath = os.path.join(steam_data, "steam_dev.cfg")
        if not os.path.exists(fpath):
            with open(fpath, "w") as f:
                f.write(cfg_content)

        # Remove stale lockfiles that prevent Steam from opening
        for lck in [".steam_is_running.lock", "steam.pid", "steam.pipe", "steam.sockets"]:
            for sdir in [steam_data, steam_link_dir, os.path.join(steam_link_dir, "root")]:
                f = os.path.join(sdir, lck)
                if os.path.exists(f):
                    try:
                        os.remove(f)
                    except Exception:
                        pass
    except Exception:
        pass

def clean_discord_environment():
    home = os.path.expanduser("~")
    # 1. Remove any faulty wrapper files that blocked Discord from opening normally
    for w in [os.path.join(home, ".local/bin/discord"), "/usr/local/bin/discord"]:
        if os.path.exists(w):
            try:
                os.remove(w)
            except Exception:
                try:
                    if subprocess.run(["sudo", "-n", "true"], capture_output=True).returncode == 0:
                        subprocess.run(["sudo", "rm", "-f", w], capture_output=True)
                except Exception:
                    pass

    # 2. Remove stale Electron singleton locks that cause Discord to hang / not open
    for lck in ["SingletonLock", "SingletonSocket", "SingletonCookie"]:
        f = os.path.join(home, ".config/discord", lck)
        if os.path.exists(f):
            try:
                os.remove(f)
            except Exception:
                pass

def fix_spotify_prefs():
    home = os.path.expanduser("~")
    spot_dir = os.path.join(home, ".config/spotify")
    try:
        os.makedirs(spot_dir, exist_ok=True)
        prefs_file = os.path.join(spot_dir, "prefs")
        if not os.path.exists(prefs_file):
            with open(prefs_file, "w") as f:
                f.write("app.autologin.enabled=false\n")
    except Exception:
        pass

def main():
    mons = detect_monitors()
    if mons:
        apply_monitors(mons)
    apply_mouse_dpi(1600)
    fix_steam_loopback()
    fix_steam_config()
    clean_discord_environment()
    fix_spotify_prefs()
    # Ensure night light is neutral
    try:
        subprocess.run(["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", "6500"], capture_output=True, timeout=2)
    except Exception:
        pass

if __name__ == "__main__":
    main()
