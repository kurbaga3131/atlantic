#!/usr/bin/env bash

# 1. Clean circular symlinks and prepare directories safely
if [ -L "$HOME/.local/share/Steam" ]; then
    REAL_TARGET=$(readlink -f "$HOME/.local/share/Steam" 2>/dev/null || true)
    if [ "$REAL_TARGET" = "$HOME/.steam/steam" ] || [ "$REAL_TARGET" = "$HOME/.steam/root" ] || [ ! -e "$REAL_TARGET" ]; then
        rm -f "$HOME/.local/share/Steam"
    fi
fi

mkdir -p "$HOME/.local/share/Steam" "$HOME/.steam"

# Migrate files if ~/.steam/steam or root was created as a real directory instead of symlink
if [ -d "$HOME/.steam/steam" ] && [ ! -L "$HOME/.steam/steam" ]; then
    cp -rn "$HOME/.steam/steam/"* "$HOME/.local/share/Steam/" 2>/dev/null || true
    rm -rf "$HOME/.steam/steam"
fi
if [ -d "$HOME/.steam/root" ] && [ ! -L "$HOME/.steam/root" ]; then
    cp -rn "$HOME/.steam/root/"* "$HOME/.local/share/Steam/" 2>/dev/null || true
    rm -rf "$HOME/.steam/root"
fi

# Ensure standard Arch symlinks exist
ln -sfn "$HOME/.local/share/Steam" "$HOME/.steam/steam"
ln -sfn "$HOME/.local/share/Steam" "$HOME/.steam/root"

# 2. Kill orphan background processes and clean stale lockfiles
# If the main Steam process is NOT active, any lingering steamwebhelper is a dead orphan
if ! pgrep -x steam >/dev/null 2>&1 && ! pgrep -f "steam.sh" >/dev/null 2>&1 && ! pgrep -f "ubuntu12_32/steam" >/dev/null 2>&1 && ! pgrep -f "ubuntu12_64/steam" >/dev/null 2>&1; then
    pkill -9 -f "steamwebhelper" 2>/dev/null || true
    rm -f "$HOME/.local/share/Steam/.steam_is_running.lock" \
          "$HOME/.local/share/Steam/steam.pid" \
          "$HOME/.local/share/Steam/steam.pipe" \
          "$HOME/.steam/steam.pid" \
          "$HOME/.steam/steam.pipe" \
          "$HOME/.steam/steam.sockets" \
          "$HOME/.steam/root/steam.pid" \
          "$HOME/.steam/root/steam.pipe" \
          "$HOME/.steam/root/steam.sockets" 2>/dev/null || true
fi

# 3. Disable HTTP/2 download throttle for maximum speed
if [ ! -f "$HOME/.local/share/Steam/steam_dev.cfg" ]; then
    cat << "EOF" > "$HOME/.local/share/Steam/steam_dev.cfg"
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF
fi

# 4. Safe locale configuration:
# - Unset LC_ALL so Steam localization and UI language catalogs work properly (prevents language failed crash)
# - Set LC_CTYPE to C.UTF-8 (or en_US.UTF-8) to protect against the glibc Turkish dotless 'ı' crash
unset LC_ALL
if locale -a 2>/dev/null | grep -qi "^en_US\.utf8"; then
    export LANG="${LANG:-en_US.UTF-8}"
    export LC_CTYPE="en_US.UTF-8"
else
    export LC_CTYPE="C.UTF-8"
fi

# Clear Wayland clipboard if wl-copy exists (prevents Wayland CEF clipboard deadlock)
command -v wl-copy >/dev/null 2>&1 && wl-copy --clear 2>/dev/null || true

# 5. Check if Steam is already installed and bootstrapped
is_steam_installed() {
    [ -f "$HOME/.local/share/Steam/steam.sh" ] || \
    [ -f "$HOME/.steam/steam/steam.sh" ] || \
    [ -f "$HOME/.steam/root/steam.sh" ] || \
    [ -d "$HOME/.local/share/Steam/package" ] || \
    [ -d "$HOME/.steam/steam/package" ] || \
    [ -x "$HOME/.local/share/Steam/ubuntu12_32/steam" ] || \
    [ -x "$HOME/.local/share/Steam/ubuntu12_64/steam" ] || \
    [ -f "$HOME/.local/share/Steam/ubuntu12_32/steam" ] || \
    [ -f "$HOME/.local/share/Steam/ubuntu12_64/steam" ]
}

if is_steam_installed; then
    steam "$@" &
    exit 0
fi

# 6. First-time setup ONLY: launch in floating terminal so user sees live download progress
if command -v kitty >/dev/null 2>&1; then
    kitty --class steam-installer --title "Steam Setup" -e bash -c '
        unset LC_ALL
        if locale -a 2>/dev/null | grep -qi "^en_US\.utf8"; then
            export LANG="${LANG:-en_US.UTF-8}"
            export LC_CTYPE="en_US.UTF-8"
        else
            export LC_CTYPE="C.UTF-8"
        fi
        echo -e "\033[1;36m===================================================\033[0m"
        echo -e "\033[1;32m       Steam İlk Kurulumu ve İndirmesi            \033[0m"
        echo -e "\033[1;36m===================================================\033[0m"
        echo -e "\033[0;33mSteam paketleri indiriliyor ve kuruluyor...\033[0m"
        echo -e "\033[0;33mLütfen bu pencereyi kapatmayın, indirme bitince Steam açılacaktır.\033[0m\n"
        steam "$@"
        STATUS=$?
        if [ $STATUS -ne 0 ]; then
            echo -e "\n\033[1;31m[HATA] Steam başlatılırken bir sorun oluştu (Kod: $STATUS).\033[0m"
            echo "Ayrıntıları yukarıda görebilirsiniz. Kapatmak için Enter tuşuna basın..."
            read -r
        fi
    ' &
else
    steam "$@" &
fi
