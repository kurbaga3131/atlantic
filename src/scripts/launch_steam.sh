#!/usr/bin/env bash

# 1. Fix symlinks for Arch Linux Steam
[ -d "$HOME/.steam/steam" ] && [ ! -L "$HOME/.steam/steam" ] && rm -rf "$HOME/.steam/steam"
[ -d "$HOME/.steam/root" ] && [ ! -L "$HOME/.steam/root" ] && rm -rf "$HOME/.steam/root"
mkdir -p "$HOME/.local/share/Steam" "$HOME/.steam"
ln -sfn "$HOME/.local/share/Steam" "$HOME/.steam/steam"
ln -sfn "$HOME/.local/share/Steam" "$HOME/.steam/root"

# 2. Disable HTTP/2 download throttle for maximum speed
if [ ! -f "$HOME/.local/share/Steam/steam_dev.cfg" ]; then
    cat << "EOF" > "$HOME/.local/share/Steam/steam_dev.cfg"
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF
fi

# 3. Clean stale lockfiles ONLY if Steam is not currently running
if ! pgrep -x steam >/dev/null 2>&1 && ! pgrep -f "ubuntu12_32/steam" >/dev/null 2>&1; then
    rm -f "$HOME/.local/share/Steam/.steam_is_running.lock" "$HOME/.steam/steam.pid" "$HOME/.steam/steam.pipe" 2>/dev/null || true
fi

# 4. Check if Steam has already completed initial bootstrap
IS_FIRST_RUN=false
if [ ! -d "$HOME/.local/share/Steam/ubuntu12_32/steam-runtime" ]; then
    IS_FIRST_RUN=true
fi

# 5. Launch Steam
(gtk-launch steam 2>/dev/null || steam) &

# 6. If first run, show Zenity progress dialog matching Discord's dialog
if [ "$IS_FIRST_RUN" = true ] && command -v zenity >/dev/null 2>&1; then
    (
        zenity --progress \
            --title="Progress" \
            --text="Downloading Steam..." \
            --pulsate \
            --auto-close \
            --no-cancel 2>/dev/null &
        ZEN_PID=$!

        for i in {1..300}; do
            sleep 1
            # Close dialog if Steam window appeared
            if command -v hyprctl >/dev/null 2>&1 && hyprctl clients 2>/dev/null | grep -i "class:.*steam" >/dev/null 2>&1; then
                kill "$ZEN_PID" 2>/dev/null || true
                break
            fi
            # Close dialog if steam-runtime is installed
            if [ -d "$HOME/.local/share/Steam/ubuntu12_32/steam-runtime" ]; then
                sleep 2
                kill "$ZEN_PID" 2>/dev/null || true
                break
            fi
            # Close dialog if steam died
            if ! pgrep -x steam >/dev/null 2>&1 && ! pgrep -f "ubuntu12_32/steam" >/dev/null 2>&1; then
                kill "$ZEN_PID" 2>/dev/null || true
                break
            fi
        done
        kill "$ZEN_PID" 2>/dev/null || true
    ) &
fi
