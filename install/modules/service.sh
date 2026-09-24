#!/usr/bin/env bash

detect_init_system() {
    if [[ -d /run/systemd/system ]] || command -v systemctl &>/dev/null; then
        echo "systemd"
    elif command -v openrc-init &>/dev/null || [[ -d /run/openrc ]]; then
        echo "openrc"
    elif command -v dinit &>/dev/null || [[ -d /etc/dinit.d ]]; then
        echo "dinit"
    elif command -v runit &>/dev/null || [[ -d /run/runit ]]; then
        echo "runit"
    elif command -v s6-svscan &>/dev/null; then
        echo "s6"
    else
        echo "generic"
    fi
}

enable_system_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            sudo systemctl enable --now "$svc.service" 2>/dev/null || sudo systemctl enable -f "$svc.service" 2>/dev/null || sudo systemctl enable "$svc.service" 2>/dev/null || true
            ;;
        openrc)
            sudo rc-update add "$svc" default 2>/dev/null || true
            sudo rc-service "$svc" start 2>/dev/null || true
            ;;
        dinit)
            sudo dinitctl enable "$svc" 2>/dev/null || sudo dinitctl start "$svc" 2>/dev/null || true
            ;;
        runit)
            if [ -d "/etc/sv/$svc" ]; then
                sudo ln -sf "/etc/sv/$svc" /var/service/ 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b add default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

disable_system_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            sudo systemctl disable --now "$svc.service" 2>/dev/null || sudo systemctl disable "$svc.service" 2>/dev/null || sudo systemctl disable "$svc" 2>/dev/null || true
            ;;
        openrc)
            sudo rc-service "$svc" stop 2>/dev/null || true
            sudo rc-update del "$svc" default 2>/dev/null || true
            ;;
        dinit)
            sudo dinitctl stop "$svc" 2>/dev/null || true
            sudo dinitctl disable "$svc" 2>/dev/null || true
            ;;
        runit)
            if [ -L "/var/service/$svc" ] || [ -d "/var/service/$svc" ]; then
                sudo rm -f "/var/service/$svc" 2>/dev/null || true
            fi
            ;;
        s6)
            sudo s6-rc-bundle-update -b del default "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

enable_user_service() {
    local svc="$1"
    local init_sys="$2"

    case "$init_sys" in
        systemd)
            systemctl --user daemon-reload 2>/dev/null || true
            systemctl --user enable --now "$svc.service" 2>/dev/null || systemctl --user enable "$svc.service" 2>/dev/null || true
            ;;
        dinit)
            dinitctl --user enable "$svc" 2>/dev/null || dinitctl --user start "$svc" 2>/dev/null || true
            ;;
        *)
            true
            ;;
    esac
}

setup_services() {
    local init_sys
    init_sys=$(detect_init_system)

    if [[ "$init_sys" == "systemd" ]]; then
        sudo systemctl --global enable pipewire wireplumber pipewire-pulse 2>/dev/null || true
        systemctl --user start pipewire wireplumber pipewire-pulse 2>/dev/null || true
    fi

    enable_user_service "easyeffects" "$init_sys"
    enable_system_service "NetworkManager" "$init_sys"
    enable_system_service "bluetooth" "$init_sys"
    enable_system_service "power-profiles-daemon" "$init_sys"
    enable_system_service "ratbagd" "$init_sys"

    # Cloudflare WARP requires systemd-resolved for DNS handling on Arch
    if [[ "$init_sys" == "systemd" ]]; then
        enable_system_service "systemd-resolved" "$init_sys"
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true

        if [ -d "/etc/NetworkManager" ]; then
            sudo mkdir -p /etc/NetworkManager/conf.d 2>/dev/null || true
            sudo bash -c 'cat << "EOF" > /etc/NetworkManager/conf.d/dns.conf
[main]
dns=systemd-resolved
EOF' 2>/dev/null || true
        fi
    fi

    enable_system_service "warp-svc" "$init_sys"

    # Cloudflare WARP auto-registration
    if command -v warp-cli &>/dev/null; then
        sleep 1
        warp-cli registration new 2>/dev/null || \
        warp-cli --accept-tos registration new 2>/dev/null || \
        warp-cli register 2>/dev/null || true
        warp-cli mode warp 2>/dev/null || true
        warp-cli disconnect 2>/dev/null || true
    fi

    # Ensure en_US.UTF-8 locale is generated for Steam compatibility
    if [ -f /etc/locale.gen ]; then
        if ! grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
            sudo sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || true
            sudo locale-gen >/dev/null 2>&1 || true
        fi
    fi

    # Fix Steam loopback DNS hang with systemd-resolved
    if [ -f /etc/hosts ]; then
        if ! grep -q "steamloopback.host" /etc/hosts; then
            echo -e "\n127.0.0.1 steamloopback.host\n::1 steamloopback.host" | sudo tee -a /etc/hosts >/dev/null 2>&1 || true
        fi
    fi

    # Optimize Steam client download speed (disable HTTP/2 throttling on Linux)
    local target_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$target_user" 2>/dev/null | cut -d: -f6)
    [[ -z "$user_home" ]] && user_home="$HOME"
    if [ -n "$user_home" ]; then
        mkdir -p "$user_home/.local/share/Steam" "$user_home/.steam" "$user_home/.config/spotify"
        [ ! -f "$user_home/.config/spotify/prefs" ] && echo "app.autologin.enabled=false" > "$user_home/.config/spotify/prefs"

        # CRITICAL: ~/.steam/steam and ~/.steam/root MUST be symlinks, NEVER directories!
        [ -d "$user_home/.steam/steam" ] && [ ! -L "$user_home/.steam/steam" ] && rm -rf "$user_home/.steam/steam"
        [ -d "$user_home/.steam/root" ] && [ ! -L "$user_home/.steam/root" ] && rm -rf "$user_home/.steam/root"
        ln -sfn "$user_home/.local/share/Steam" "$user_home/.steam/steam"
        ln -sfn "$user_home/.local/share/Steam" "$user_home/.steam/root"

        cat << "EOF" > "$user_home/.local/share/Steam/steam_dev.cfg"
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF
        if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
            chown -R "$target_user:" "$user_home/.local/share/Steam" "$user_home/.steam" "$user_home/.config/spotify" 2>/dev/null || true
        fi

        # Pre-bootstrap Steam client during installation so desktop click opens immediately
        if [ ! -f "$user_home/.local/share/Steam/steam.sh" ]; then
            if command -v xvfb-run &>/dev/null && command -v steam &>/dev/null; then
                echo -e "\n\e[36m[ STEAM ]\e[0m Steam ilk kurulum dosyalari indiriliyor ve hazirlaniyor..."
                local run_steam_cmd="xvfb-run -a steam -silent </dev/null >/dev/null 2>&1 &"
                if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
                    sudo -u "$SUDO_USER" -H bash -c "$run_steam_cmd"
                else
                    bash -c "$run_steam_cmd"
                fi
                local count=0
                while [ $count -lt 120 ]; do
                    if [ -f "$user_home/.local/share/Steam/steam.sh" ] && [ -d "$user_home/.local/share/Steam/package" ]; then
                        echo -e "\e[32m[ ✓ ]\e[0m Steam kurulum dosyalari basariyla tamamlandi."
                        sleep 3
                        pkill -15 -f steam 2>/dev/null || true
                        sleep 1
                        pkill -9 -f steam 2>/dev/null || true
                        pkill -9 -fi Xvfb 2>/dev/null || true
                        break
                    fi
                    sleep 1
                    count=$((count + 1))
                    printf "\r\e[36m[ STEAM ]\e[0m Steam paketleri indiriliyor (%ds)..." "$count"
                done
                pkill -15 -f steam 2>/dev/null || true
                sleep 1
                pkill -9 -f steam 2>/dev/null || true
                pkill -9 -fi Xvfb 2>/dev/null || true
                echo ""
                # If steam.sh does not exist after timeout, clear broken partial files
                if [ ! -f "$user_home/.local/share/Steam/steam.sh" ]; then
                    rm -rf "$user_home/.local/share/Steam/package" "$user_home/.local/share/Steam/tmp" 2>/dev/null || true
                fi
                if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
                    chown -R "$target_user:" "$user_home/.local/share/Steam" "$user_home/.steam" 2>/dev/null || true
                fi
            fi
        fi
    fi

    # Discord clean-launch wrapper (prevent hanging zombie processes)
    mkdir -p /usr/local/bin 2>/dev/null || true
    cat << "EOF" > /usr/local/bin/discord 2>/dev/null || sudo tee /usr/local/bin/discord >/dev/null 2>&1 || true
#!/bin/bash
# Atlantic Discord clean-launch wrapper: cleans up hanging zombie processes on start
if command -v hyprctl &>/dev/null; then
    if ! hyprctl clients -j 2>/dev/null | jq -e '.[] | select((.class // "") | test("(?i)discord|vesktop"))' >/dev/null; then
        pkill -9 -x Discord 2>/dev/null || true
        pkill -9 -fi /opt/discord/Discord 2>/dev/null || true
        sleep 0.1
    fi
fi
if [ -x /opt/discord/Discord ]; then
    exec /opt/discord/Discord "$@"
else
    exec /usr/bin/discord "$@"
fi
EOF
    chmod +x /usr/local/bin/discord 2>/dev/null || sudo chmod +x /usr/local/bin/discord 2>/dev/null || true

    # Spotify & Spicetify setup (permissions & marketplace)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local spicetify_script="$script_dir/../../src/scripts/setup_spicetify.sh"
    if [ -f "$spicetify_script" ]; then
        bash "$spicetify_script" 2>/dev/null || true
    elif [ -d "/opt/spotify" ]; then
        sudo chmod a+wr /opt/spotify /opt/spotify/Apps -R 2>/dev/null || true
    fi
}
