#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/caching.sh"
qs_ensure_cache "music"

STATE_FILE="$QS_RUN_MUSIC/eq_state.json"
PRESET_DIR1="$HOME/.config/easyeffects/output"
PRESET_DIR2="$HOME/.local/share/easyeffects/output"
PRESET_NAME="live_eq"

mkdir -p "$PRESET_DIR1" "$PRESET_DIR2"

if [ ! -f "$STATE_FILE" ]; then
    echo '{"b1": 0, "b2": 0, "b3": 0, "b4": 0, "b5": 0, "b6": 0, "b7": 0, "b8": 0, "b9": 0, "b10": 0, "preset": "Flat", "pending": false}' > "$STATE_FILE"
fi

apply_eq() {
    vals=$(cat "$STATE_FILE")
    json_output=$(python3 -c "
import sys, json

try:
    data = json.loads(sys.argv[1])
    freqs = [31.0, 63.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0]
    gains = [float(data.get(f'b{i+1}', 0.0)) for i in range(10)]

    left_bands = {}
    right_bands = {}
    for i in range(10):
        b = {
            'frequency': freqs[i],
            'gain': gains[i],
            'mode': 'RLC (BT)',
            'mute': False,
            'q': 1.6,
            'slope': 'x1',
            'solo': False,
            'type': 'Bell',
            'width': 4.0
        }
        left_bands[f'band{i}'] = b
        right_bands[f'band{i}'] = b

    eq_config = {
        'bypass': False,
        'input-gain': 0.0,
        'output-gain': 0.0,
        'left': left_bands,
        'right': right_bands,
        'mode': 'IIR',
        'num-bands': 10,
        'split-channels': False
    }

    game_blocklist = [
        "cs2", "csgo_linux64", "dota2", "deadlock", "hl2_linux", "tf_linux64",
        "portal2_linux", "left4dead2", "valheim.x86_64", "steam", "steamwebhelper",
        "gamescope", "wine-preloader", "wine64-preloader", "wine", "wine64",
        "proton", "Proton", "heroic", "lutris", "retroarch", "rpcs3", "pcsx2",
        "dolphin-emu", "yuzu", "ryujinx", "cemu", "osu!", "minecraft", "java", "javaw"
    ]

    preset = {
        'output': {
            'blocklist': game_blocklist,
            'plugins_order': [ 'equalizer#0' ],
            'equalizer#0': eq_config,
            'equalizer': eq_config
        }
    }
    print(json.dumps(preset, indent=4))

    # Also persist to easyeffectsrc database
    import os
    try:
        db_dir = os.path.expanduser("~/.config/easyeffects/db")
        os.makedirs(db_dir, exist_ok=True)
        db_file = os.path.join(db_dir, "easyeffectsrc")
        lines = []
        if os.path.exists(db_file):
            with open(db_file, "r") as f:
                lines = f.readlines()
        has_so = False
        new_lines = []
        bl_str = ",".join(game_blocklist)
        for line in lines:
            if line.strip().startswith("[StreamOutputs]"):
                has_so = True
            if line.strip().startswith("blocklist="):
                continue
            new_lines.append(line)
            if has_so and line.strip().startswith("[StreamOutputs]"):
                new_lines.append(f"blocklist={bl_str}\n")
        if not has_so:
            new_lines.append(f"\n[StreamOutputs]\nblocklist={bl_str}\n")
        with open(db_file, "w") as f:
            f.writelines(new_lines)
    except Exception:
        pass
except Exception:
    sys.exit(1)
" "$vals")

    if [ -n "$json_output" ]; then
        echo "$json_output" > "$PRESET_DIR1/${PRESET_NAME}.json"
        echo "$json_output" > "$PRESET_DIR2/${PRESET_NAME}.json"
    fi

    # Ensure EasyEffects routes all outputs to the virtual sink and bypass is off
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set com.github.wwmm.easyeffects process-all-outputs true 2>/dev/null || true
        gsettings set com.github.wwmm.easyeffects bypass false 2>/dev/null || true
    fi

    # Ensure EasyEffects daemon is running
    if ! pgrep -x easyeffects >/dev/null 2>&1 && ! pgrep -f "easyeffects --gapplication-service" >/dev/null 2>&1; then
        easyeffects --gapplication-service >/dev/null 2>&1 &
        for i in {1..15}; do
            if pgrep -x easyeffects >/dev/null 2>&1 || pgrep -f "easyeffects --gapplication-service" >/dev/null 2>&1; then
                sleep 0.4
                break
            fi
            sleep 0.1
        done
    fi

    # Apply preset live
    easyeffects -l "$PRESET_NAME" >/dev/null 2>&1 &
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
    "get") cat "$STATE_FILE" ;;
    "set_band")
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c --arg val "$arg2" ".b$arg1 = \$val | .preset = \"Custom\" | .pending = true")
        echo "$updated" > "$STATE_FILE"
        ;;
    "apply")
        tmp=$(cat "$STATE_FILE")
        updated=$(echo "$tmp" | jq -c ".pending = false")
        echo "$updated" > "$STATE_FILE"
        apply_eq
        ;;
    "preset")
        case $arg1 in
            "Flat")    save_preset 0 0 0 0 0 0 0 0 0 0 "Flat" ;;
            "Bass")    save_preset 5 7 5 2 1 0 0 0 1 2 "Bass" ;;
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
