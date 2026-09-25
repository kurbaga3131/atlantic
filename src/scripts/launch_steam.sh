#!/usr/bin/env bash

# 1. Fix symlinks for Arch Linux Steam
[ -d "$HOME/.steam/steam" ] && [ ! -L "$HOME/.steam/steam" ] && rm -rf "$HOME/.steam/steam"
[ -d "$HOME/.steam/root" ] && [ ! -L "$HOME/.steam/root" ] && rm -rf "$HOME/.steam/root"
mkdir -p "$HOME/.local/share/Steam" "$HOME/.steam"
ln -sfn "$HOME/.local/share/Steam" "$HOME/.steam/steam"
ln -sfn "$HOME/.local/share/Steam" "$HOME/.steam/root"

# 2. Set safe UTF-8 locale to prevent Turkish glibc dotless 'ı' crash
if locale -a 2>/dev/null | grep -qi "^en_US\.utf8"; then
    export LC_ALL="en_US.UTF-8"
    export LANG="en_US.UTF-8"
else
    export LC_ALL="C.UTF-8"
    export LANG="C.UTF-8"
fi

# 3. Disable HTTP/2 download throttle for maximum speed
if [ ! -f "$HOME/.local/share/Steam/steam_dev.cfg" ]; then
    cat << "EOF" > "$HOME/.local/share/Steam/steam_dev.cfg"
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF
fi

# 4. Clean stale lockfiles ONLY if Steam is not currently running
if ! pgrep -f "ubuntu12_32/steam" >/dev/null 2>&1 && ! pgrep -f "steamwebhelper" >/dev/null 2>&1; then
    rm -f "$HOME/.local/share/Steam/.steam_is_running.lock" \
          "$HOME/.steam/steam.pid" \
          "$HOME/.steam/steam.pipe" \
          "$HOME/.steam/steam.sockets" 2>/dev/null || true
fi

# 5. If Steam is already installed and bootstrapped, launch directly
if [ -x "$HOME/.local/share/Steam/ubuntu12_32/steam" ]; then
    steam "$@" &
    exit 0
fi

# 6. First-time setup: launch in floating terminal so user sees live download progress
if command -v kitty >/dev/null 2>&1; then
    kitty --class steam-installer --title "Steam Setup" -e bash -c '
        if locale -a 2>/dev/null | grep -qi "^en_US\.utf8"; then
            export LC_ALL="en_US.UTF-8"
            export LANG="en_US.UTF-8"
        else
            export LC_ALL="C.UTF-8"
            export LANG="C.UTF-8"
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

