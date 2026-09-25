#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh" 2>/dev/null || true
if [ -z "$QS_RUN_MUSIC" ]; then
    QS_RUN_MUSIC="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/atlantic/music"
    mkdir -p "$QS_RUN_MUSIC"
fi

STATE_FILE="$QS_RUN_MUSIC/eq_state.json"
PRESET_DIR1="$HOME/.config/easyeffects/output"
PRESET_DIR2="$HOME/.local/share/easyeffects/output"
PRESET_NAME="live_eq"

mkdir -p "$PRESET_DIR1" "$PRESET_DIR2"

if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "pending": false}' > "$STATE_FILE"
fi

apply_eq() {
    vals=$(cat "$STATE_FILE" 2>/dev/null || echo '{"b1":0}')

    # 1. Generate 32-band EasyEffects preset matching GUI structure
    python3 -c '
import sys, json, math, os, socket

try:
    data = json.loads(sys.argv[1])
    anchors = [31.0, 63.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0]
    user_gains = [float(data.get("b" + str(i + 1), 0.0)) for i in range(10)]

    freqs_32 = [
        22.0, 28.0, 35.0, 45.0, 57.0, 71.0, 90.0, 112.0,
        141.0, 178.0, 224.0, 282.0, 355.0, 447.0, 562.0, 708.0,
        891.0, 1122.0, 1414.0, 1782.0, 2245.0, 2828.0, 3564.0, 4490.0,
        5657.0, 7127.0, 8980.0, 11314.0, 14254.0, 17959.0, 20000.0, 22000.0
    ]

    log_anchors = [math.log10(a) for a in anchors]
    interpolated_gains = []
    for f in freqs_32:
        lf = math.log10(f)
        if lf <= log_anchors[0]:
            g = user_gains[0]
        elif lf >= log_anchors[-1]:
            g = user_gains[-1]
        else:
            for i in range(len(log_anchors) - 1):
                if log_anchors[i] <= lf <= log_anchors[i + 1]:
                    t = (lf - log_anchors[i]) / (log_anchors[i + 1] - log_anchors[i])
                    g = user_gains[i] * (1.0 - t) + user_gains[i + 1] * t
                    break
        interpolated_gains.append(round(g, 1))

    left_bands = {}
    right_bands = {}
    for i in range(32):
        b = {
            "frequency": freqs_32[i],
            "gain": interpolated_gains[i],
            "mode": "RLC (BT)",
            "mute": False,
            "q": 4.36,
            "slope": "x1",
            "solo": False,
            "type": "Bell",
            "width": 4.0
        }
        left_bands["band" + str(i)] = b
        right_bands["band" + str(i)] = b

    eq_config = {
        "bypass": False,
        "input-gain": 0.0,
        "output-gain": 0.0,
        "left": left_bands,
        "right": right_bands,
        "mode": "IIR",
        "num-bands": 32,
        "split-channels": False
    }

    game_blocklist = [
        "cs2", "csgo_linux64", "dota2", "deadlock", "hl2_linux", "tf_linux64",
        "portal2_linux", "left4dead2", "valheim.x86_64", "steam", "steamwebhelper",
        "gamescope", "wine-preloader", "wine64-preloader", "wine", "wine64",
        "proton", "Proton", "heroic", "lutris", "retroarch", "rpcs3", "pcsx2",
        "dolphin-emu", "yuzu", "ryujinx", "cemu", "osu!", "minecraft", "java", "javaw"
    ]

    preset = {
        "output": {
            "blocklist": game_blocklist,
            "plugins_order": [ "equalizer#0" ],
            "equalizer#0": eq_config,
            "equalizer": eq_config
        }
    }
    preset_json = json.dumps(preset, indent=4)

    # Save to both paths
    p1 = os.path.expanduser("~/.config/easyeffects/output/live_eq.json")
    p2 = os.path.expanduser("~/.local/share/easyeffects/output/live_eq.json")
    os.makedirs(os.path.dirname(p1), exist_ok=True)
    os.makedirs(os.path.dirname(p2), exist_ok=True)
    with open(p1, "w") as f:
        f.write(preset_json)
    with open(p2, "w") as f:
        f.write(preset_json)

    # 2. Directly send command to EasyEffects Unix domain socket
    runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    sock_path = os.path.join(runtime_dir, "EasyEffectsServer")
    if os.path.exists(sock_path):
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(1.0)
            s.connect(sock_path)
            s.sendall(b"load_preset:output:live_eq\n")
            s.close()
        except Exception:
            pass

except Exception:
    sys.exit(1)
' "$vals"

    # 3. Also notify via socat over the Unix socket if available
    SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/EasyEffectsServer"
    if [ -S "$SOCK" ] && command -v socat >/dev/null 2>&1; then
        echo "load_preset:output:live_eq" | socat - UNIX-CONNECT:"$SOCK" 2>/dev/null || true
    fi

    # 4. CLI command fallback
    easyeffects --load-preset "live_eq" >/dev/null 2>&1 || easyeffects -l "live_eq" >/dev/null 2>&1 || true

    # 5. Ensure EasyEffects routes all outputs to the virtual sink and bypass is off
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set com.github.wwmm.easyeffects process-all-outputs true 2>/dev/null || true
        gsettings set com.github.wwmm.easyeffects bypass false 2>/dev/null || true
    fi

    # 6. Ensure EasyEffects daemon is running
    if ! pgrep -x easyeffects >/dev/null 2>&1 && ! pgrep -f "easyeffects --gapplication-service" >/dev/null 2>&1; then
        easyeffects --gapplication-service >/dev/null 2>&1 &
        for i in {1..20}; do
            if [ -S "$SOCK" ]; then
                sleep 0.2
                echo "load_preset:output:live_eq" | socat - UNIX-CONNECT:"$SOCK" 2>/dev/null || true
                break
            fi
            sleep 0.1
        done
    fi

    # 7. Ensure easyeffects_sink is set as default sink in PipeWire if present
    if command -v pactl >/dev/null 2>&1; then
        pactl set-default-sink easyeffects_sink 2>/dev/null || true
    fi
    if command -v wpctl >/dev/null 2>&1; then
        EE_SINK=$(wpctl status 2>/dev/null | grep -E "easyeffects_sink" | grep -oE "[0-9]+" | head -n 1)
        if [ -n "$EE_SINK" ]; then
            wpctl set-default "$EE_SINK" 2>/dev/null || true
        fi
    fi
}

save_preset() {
    jq -n -c --arg b1 "$1" --arg b2 "$2" --arg b3 "$3" --arg b4 "$4" --arg b5 "$5" \
          --arg b6 "$6" --arg b7 "$7" --arg b8 "$8" --arg b9 "$9" --arg b10 "${10}" --arg p "${11}" \
       '{"b1": $b1, "b2": $b2, "b3": $b3, "b4": $b4, "b5": $b5, "b6": $b6, "b7": $b7, "b8": $b8, "b9": $b9, "b10": $b10, "preset": $p, "pending": false}' > "$STATE_FILE"
}

cmd=$1
arg1=$2
arg2=$3

case $cmd in
    "get") cat "$STATE_FILE" 2>/dev/null || echo '{"b1":0}' ;;
    "set_band")
        tmp=$(cat "$STATE_FILE" 2>/dev/null || echo '{"b1":0}')
        updated=$(echo "$tmp" | jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true")
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "apply")
        tmp=$(cat "$STATE_FILE" 2>/dev/null || echo '{"b1":0}')
        updated=$(echo "$tmp" | jq -c ".pending = false")
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "preset")
        case $arg1 in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 6 7 5 3 1 0 0 0 1 2 "Bass" ;;
            "Treble")  save_preset -2 -1 0 1 2 3 4 5 6 6 "Treble" ;;
            "Vocal")   save_preset -2 -1 1 3 5 5 4 2 1 0 "Vocal" ;;
            "Pop")     save_preset 2 4 2 0 1 2 4 2 1 2 "Pop" ;;
            "Rock")    save_preset 5 4 2 -1 -2 -1 2 4 5 6 "Rock" ;;
            "Jazz")    save_preset 3 3 1 1 1 1 2 1 2 3 "Jazz" ;;
            "Classic") save_preset 0 1 2 2 2 2 1 2 3 4 "Classic" ;;
        esac
        apply_eq
        ;;
esac
