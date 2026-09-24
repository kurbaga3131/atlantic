#!/usr/bin/env bash

EXTRA_CONFIGS=(
    "kitty"
    "cava"
    "fastfetch"
)

render_wallpaper_progress() {
    local current="$1"
    local total="$2"
    local label="${3:-Installing wallpapers}"
    local bar_width=30
    local percent=0
    if [ "$total" -gt 0 ]; then
        percent=$(( current * 100 / total ))
    fi
    local filled=0
    if [ "$total" -gt 0 ]; then
        filled=$(( current * bar_width / total ))
    fi
    local empty=$(( bar_width - filled ))
    local bar_fill=""
    local bar_empty=""
    if [ "$filled" -gt 0 ]; then
        bar_fill=$(printf "%*s" "$filled" "" | tr ' ' '=')
    fi
    if [ "$empty" -gt 0 ]; then
        bar_empty=$(printf "%*s" "$empty" "" | tr ' ' ' ')
    fi
    printf "\r\e[36m[ INFO ]\e[0m %s \e[32m[%s%s]\e[0m %3d%% (%d/%d)" "$label" "$bar_fill" "$bar_empty" "$percent" "$current" "$total"
}

get_wallpaper_dir() {
    local user_pics=""
    if [ -f "$HOME/.config/user-dirs.dirs" ]; then
        user_pics=$(grep '^XDG_PICTURES_DIR' "$HOME/.config/user-dirs.dirs" 2>/dev/null | cut -d= -f2 | tr -d '"' | sed "s|\$HOME|$HOME|g" || true)
    fi
    if [[ -z "$user_pics" || "$user_pics" == "$HOME" ]]; then
        if command -v xdg-user-dir &>/dev/null; then
            user_pics="$(xdg-user-dir PICTURES 2>/dev/null || true)"
        fi
    fi
    if [[ -z "$user_pics" || "$user_pics" == "$HOME" ]]; then
        user_pics="$HOME/Pictures"
    fi
    user_pics="${user_pics%/}"
    echo "$user_pics/Wallpapers"
}

install_wallpapers() {
    local full_pack="${1:-true}"
    local wallpaper_dir
    wallpaper_dir=$(get_wallpaper_dir)
    local avatar_dir="$(dirname "$wallpaper_dir")/Avatars"
    local debug_log="$HOME/wallpaper_debug.log"
    local repo_slug="${REPO_SLUG:-kurbaga3131/atlantic}"

    mkdir -p "$wallpaper_dir" 2>/dev/null || true
    mkdir -p "$avatar_dir" 2>/dev/null || true

    if [[ "$INSTALL_STATE" != "current" && "$IS_REINSTALL" == "true" ]]; then
        rm -rf "$wallpaper_dir"/* 2>/dev/null || true
        rm -rf "$avatar_dir"/* 2>/dev/null || true
    fi

    echo -e "\n\e[36m[ INFO ]\e[0m Installing wallpapers and avatars..."

    # Try local copy first
    local wp_count=0
    if [ -d "$PROJECT_ROOT/wallpapers" ]; then
        wp_count=$(find "$PROJECT_ROOT/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mkv" \) 2>/dev/null | wc -l)
    fi

    if [ "$wp_count" -gt 0 ]; then
        echo -e "  \e[36m[ INFO ]\e[0m Copying $wp_count wallpapers from local repo..."
        find "$PROJECT_ROOT/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" -o -iname "*.mp4" -o -iname "*.mkv" \) -exec cp {} "$wallpaper_dir/" \; 2>>"$debug_log" || true
    else
        echo -e "  \e[33m[ WARN ]\e[0m Local wallpapers not found, downloading from GitHub..."
        if command -v curl &>/dev/null; then
            local api_url="https://api.github.com/repos/${repo_slug}/contents/wallpapers?ref=main"
            local file_list
            file_list=$(curl -s "$api_url" 2>/dev/null | grep -o '"download_url":"[^"]*"' | cut -d'"' -f4) || true
            if [ -n "$file_list" ]; then
                local dl_count=0
                while IFS= read -r url; do
                    [ -z "$url" ] && continue
                    local fname
                    fname=$(basename "$url")
                    echo -ne "\r  Downloading: $fname...                    "
                    curl -sL "$url" -o "$wallpaper_dir/$fname" 2>/dev/null || true
                    dl_count=$((dl_count + 1))
                done <<< "$file_list"
                echo -e "\r  \e[32m[ OK ]\e[0m Downloaded $dl_count wallpapers                    "
            fi
        fi
    fi

    # Avatars - local copy first, then GitHub fallback
    local av_count=0
    if [ -d "$PROJECT_ROOT/avatars" ]; then
        av_count=$(find "$PROJECT_ROOT/avatars" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) 2>/dev/null | wc -l)
    fi

    if [ "$av_count" -gt 0 ]; then
        echo -e "  \e[36m[ INFO ]\e[0m Copying $av_count avatars from local repo..."
        find "$PROJECT_ROOT/avatars" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -exec cp {} "$avatar_dir/" \; 2>>"$debug_log" || true
    else
        echo -e "  \e[33m[ WARN ]\e[0m Local avatars not found, downloading from GitHub..."
        if command -v curl &>/dev/null; then
            local api_url="https://api.github.com/repos/${repo_slug}/contents/avatars?ref=main"
            local file_list
            file_list=$(curl -s "$api_url" 2>/dev/null | grep -o '"download_url":"[^"]*"' | cut -d'"' -f4) || true
            if [ -n "$file_list" ]; then
                local dl_count=0
                while IFS= read -r url; do
                    [ -z "$url" ] && continue
                    local fname
                    fname=$(basename "$url")
                    curl -sL "$url" -o "$avatar_dir/$fname" 2>/dev/null || true
                    dl_count=$((dl_count + 1))
                done <<< "$file_list"
                echo -e "  \e[32m[ OK ]\e[0m Downloaded $dl_count avatars"
            fi
        fi
    fi

    # Debug log
    {
        echo "=== WALLPAPER DEBUG LOG ==="
        echo "PROJECT_ROOT=$PROJECT_ROOT"
        echo "Local wallpapers found: $wp_count"
        echo "Local avatars found: $av_count"
        echo "Installed wallpapers: $(find "$wallpaper_dir" -type f 2>/dev/null | wc -l)"
        echo "Installed avatars: $(find "$avatar_dir" -type f 2>/dev/null | wc -l)"
    } >> "$debug_log" 2>&1 || true
}

setup_sddm() {
    local project_root="$1"
    local install_state="${2:-$INSTALL_STATE}"
    local is_reinstall="${3:-$IS_REINSTALL}"

    if [ "$OPT_SDDM" != true ]; then
        return 0
    fi

    local is_update=false
    if [[ "$install_state" == "current" && "$is_reinstall" != "true" ]]; then
        is_update=true
    fi

    local init_sys="generic"
    if declare -f detect_init_system >/dev/null; then
        init_sys=$(detect_init_system)
    fi

    echo -e "\n\e[36m[ INFO ]\e[0m $(t "installer.deploy.configuring_sddm")"

    if [ "$is_update" != true ] && [ "$REPLACE_DM" = true ]; then
        local dms=("gdm" "gdm3" "lightdm" "lxdm" "lxdm-gtk3" "ly" "greetd" "emptty")
        for dm in "${dms[@]}"; do
            if declare -f disable_system_service >/dev/null; then
                disable_system_service "$dm" "$init_sys"
            fi
            if command -v pacman &>/dev/null; then
                if pacman -Qq "$dm" &>/dev/null; then
                    echo "  $(t "installer.deploy.disabling_dm" "dm=$dm")"
                    sudo pacman -Rns --noconfirm "$dm" >/dev/null 2>&1 || true
                fi
            fi
        done
    fi

    sudo rm -rf /usr/share/sddm/themes/matugen-minimal
    sudo rm -rf /usr/share/sddm/themes/material-you
    sudo rm -f /etc/sddm.conf.d/*matugen*.conf
    sudo rm -f /etc/sddm.conf.d/*material-you*.conf

    if [ "$is_update" != true ] && [ -f /etc/sddm.conf ]; then
        sudo cp -a /etc/sddm.conf "/etc/sddm.conf.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        sudo rm -f /etc/sddm.conf
    fi

    local sddm_theme_src="$project_root/config/sddm/themes/material-you"
    local sddm_theme_dest="/usr/share/sddm/themes/material-you"

    if [ -d "$sddm_theme_src" ]; then
        sudo mkdir -p "$sddm_theme_dest"
        sudo cp -r "$sddm_theme_src/." "$sddm_theme_dest/"
        sudo chmod -R 755 "$sddm_theme_dest"
        if [ -d "$sddm_theme_src/font" ]; then
            sudo mkdir -p /usr/share/fonts/TTF
            sudo cp -r "$sddm_theme_src/font/"*.ttf /usr/share/fonts/TTF/ 2>/dev/null || true
            fc-cache -f /usr/share/fonts >/dev/null 2>&1 || true
        fi
    fi

    sudo mkdir -p /etc/sddm.conf.d

    if [ "$SDDM_WAYLAND" = true ]; then
        cat <<EOF | sudo tee /etc/sddm.conf.d/10-material-you.conf > /dev/null
[Theme]
Current=material-you
ThemeDir=/usr/share/sddm/themes

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_DISABLE_WINDOWDECORATION=1
InputMethod=
EOF
    else
        cat <<EOF | sudo tee /etc/sddm.conf.d/10-material-you.conf > /dev/null
[Theme]
Current=material-you
ThemeDir=/usr/share/sddm/themes

[General]
InputMethod=
EOF
    fi

    if declare -f enable_system_service >/dev/null; then
        # We don't use enable_system_service directly here because it might use --now
        # We manually enable without starting it, so it doesn't interrupt the installer
        if [[ "$init_sys" == "systemd" ]]; then
            sudo systemctl enable sddm.service 2>/dev/null || sudo systemctl enable sddm 2>/dev/null || true
        elif [[ "$init_sys" == "openrc" ]]; then
            sudo rc-update add sddm default 2>/dev/null || true
        elif [[ "$init_sys" == "dinit" ]]; then
            sudo dinitctl enable sddm 2>/dev/null || true
        fi
    else
        case "$init_sys" in
            systemd)
                sudo systemctl enable sddm.service 2>/dev/null || sudo systemctl enable sddm 2>/dev/null || true
                ;;
            openrc)
                sudo rc-update add sddm default 2>/dev/null || true
                ;;
            dinit)
                sudo dinitctl enable sddm 2>/dev/null || true
                ;;
            runit)
                if [ -d "/etc/sv/sddm" ]; then
                    sudo ln -sf "/etc/sv/sddm" /var/service/ 2>/dev/null || true
                fi
                ;;
            s6)
                sudo s6-rc-bundle-update -b add default sddm 2>/dev/null || true
                ;;
            *)
                sudo systemctl enable sddm.service -f 2>/dev/null || true
                ;;
        esac
    fi

    echo -e "  \e[32m$(t "installer.deploy.sddm_success")\e[0m"
}

deploy_package() {
    local REPO_ROOT="$1"
    local OLD_COMMIT="$2"
    local NEW_COMMIT="$3"
    local IS_REINSTALL="$4"
    local INSTALL_STATE="$5"
    shift 5
    local COMPOSITORS=("$@")

    local TARGET_BASE="$HOME/.local/share/atlantic"
    local BIN_DIR="$HOME/.local/bin"

    local is_update=false
    if [[ "$INSTALL_STATE" == "current" && "$IS_REINSTALL" != "true" ]]; then
        is_update=true
    fi

    local do_full_deploy=true

    if [ "$IS_REINSTALL" != "true" ] && [ -n "$OLD_COMMIT" ] && [ "$OLD_COMMIT" != "unknown" ] && [ -d "$REPO_ROOT/.git" ]; then
        if git -C "$REPO_ROOT" cat-file -e "$OLD_COMMIT" 2>/dev/null; then
            do_full_deploy=false
        fi
    fi

    if [ "$do_full_deploy" = true ]; then
        rm -rf "$TARGET_BASE"
        mkdir -p "$TARGET_BASE/bin" "$TARGET_BASE/src" "$BIN_DIR"

        if [ -d "$REPO_ROOT/bin" ] && [ "$(ls -A "$REPO_ROOT/bin" 2>/dev/null)" ]; then
            cp -r "$REPO_ROOT/bin/." "$TARGET_BASE/bin/"
            chmod +x "$TARGET_BASE/bin/"* 2>/dev/null || true
        fi

        if [ -d "$REPO_ROOT/src" ] && [ "$(ls -A "$REPO_ROOT/src" 2>/dev/null)" ]; then
            cp -r "$REPO_ROOT/src/." "$TARGET_BASE/src/"
            find "$TARGET_BASE/src/scripts" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
        fi

        if [ -f "$REPO_ROOT/version.txt" ]; then
            cp "$REPO_ROOT/version.txt" "$TARGET_BASE/" 2>/dev/null || true
            cp "$REPO_ROOT/version.txt" "$TARGET_BASE/src/" 2>/dev/null || true
        fi

        for cfg in "${EXTRA_CONFIGS[@]}"; do
            local src_cfg="$REPO_ROOT/config/$cfg"
            local dest_cfg="$HOME/.config/$cfg"
            if [ -d "$src_cfg" ]; then
                mkdir -p "$dest_cfg"
                cp -r "$src_cfg/." "$dest_cfg/"
            elif [ -f "$src_cfg" ]; then
                mkdir -p "$(dirname "$dest_cfg")"
                cp "$src_cfg" "$dest_cfg"
            fi
        done

        for comp in "${COMPOSITORS[@]}"; do
            local target_config_name
            case "$comp" in
                hyprland) target_config_name="hypr" ;;
                niri) target_config_name="niri" ;;
                sway) target_config_name="sway" ;;
                *) target_config_name="$comp" ;;
            esac

            local TARGET_CONFIG_DIR="$HOME/.config/$target_config_name"
            local BACKUP_BASE="$HOME/.config/${target_config_name}_backup"
            local BACKUP_DIR="$BACKUP_BASE/backup_$(date +%Y%m%d_%H%M%S)"

            local SRC_COMP_DIR=""
            if [ -d "$REPO_ROOT/compositors/$comp" ] && [ "$(ls -A "$REPO_ROOT/compositors/$comp" 2>/dev/null)" ]; then
                SRC_COMP_DIR="$REPO_ROOT/compositors/$comp"
            elif [ -d "$REPO_ROOT/compositor/$comp" ] && [ "$(ls -A "$REPO_ROOT/compositor/$comp" 2>/dev/null)" ]; then
                SRC_COMP_DIR="$REPO_ROOT/compositor/$comp"
            fi

            if [ -n "$SRC_COMP_DIR" ]; then
                if [ -d "$TARGET_CONFIG_DIR" ] && [ "$(ls -A "$TARGET_CONFIG_DIR" 2>/dev/null)" ]; then
                    mkdir -p "$BACKUP_DIR"
                    cp -a "$TARGET_CONFIG_DIR/." "$BACKUP_DIR/" 2>/dev/null || true
                fi

                local saved_mon_file=""
                local saved_mon_dest=""
                if [ "$is_update" = true ]; then
                    if [ -f "$TARGET_CONFIG_DIR/config/monitors.lua" ]; then
                        saved_mon_file="$(mktemp)"
                        cp "$TARGET_CONFIG_DIR/config/monitors.lua" "$saved_mon_file"
                        saved_mon_dest="$TARGET_CONFIG_DIR/config/monitors.lua"
                    elif [ -f "$TARGET_CONFIG_DIR/config/output.kdl" ]; then
                        saved_mon_file="$(mktemp)"
                        cp "$TARGET_CONFIG_DIR/config/output.kdl" "$saved_mon_file"
                        saved_mon_dest="$TARGET_CONFIG_DIR/config/output.kdl"
                    elif [ -f "$TARGET_CONFIG_DIR/configDir/output" ]; then
                        saved_mon_file="$(mktemp)"
                        cp "$TARGET_CONFIG_DIR/configDir/output" "$saved_mon_file"
                        saved_mon_dest="$TARGET_CONFIG_DIR/configDir/output"
                    fi
                fi

                mkdir -p "$TARGET_CONFIG_DIR"
                cp -r "$SRC_COMP_DIR/." "$TARGET_CONFIG_DIR/"

                if [ -n "$saved_mon_file" ] && [ -f "$saved_mon_file" ]; then
                    mkdir -p "$(dirname "$saved_mon_dest")"
                    cp "$saved_mon_file" "$saved_mon_dest"
                    rm -f "$saved_mon_file"
                fi

                find "$TARGET_CONFIG_DIR" -type f -o -type l | while IFS= read -r dest_file; do
                    local rel_path="${dest_file#$TARGET_CONFIG_DIR/}"
                    if [ ! -e "$SRC_COMP_DIR/$rel_path" ] && [ ! -L "$SRC_COMP_DIR/$rel_path" ]; then
                        rm -f "$dest_file"
                    fi
                done

                find "$TARGET_CONFIG_DIR" -depth -type d -empty ! -path "$TARGET_CONFIG_DIR" -delete 2>/dev/null || true
            fi
        done
    else
        mkdir -p "$TARGET_BASE/bin" "$TARGET_BASE/src" "$BIN_DIR"

        local changed_files=""
        local deleted_files=""

        if [ "$OLD_COMMIT" != "$NEW_COMMIT" ]; then
            changed_files=$(git -C "$REPO_ROOT" diff --name-only --no-renames --diff-filter=AM "$OLD_COMMIT" "$NEW_COMMIT" 2>/dev/null || true)
            deleted_files=$(git -C "$REPO_ROOT" diff --name-only --no-renames --diff-filter=D "$OLD_COMMIT" "$NEW_COMMIT" 2>/dev/null || true)
        fi

        if [ -n "$deleted_files" ]; then
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                if [[ "$file" == bin/* ]]; then
                    rm -f "$TARGET_BASE/$file"
                elif [[ "$file" == src/* ]]; then
                    rm -f "$TARGET_BASE/$file"
                elif [[ "$file" == config/* ]]; then
                    local rel_cfg="${file#config/}"
                    local cfg_name="${rel_cfg%%/*}"
                    for cfg in "${EXTRA_CONFIGS[@]}"; do
                        if [[ "$cfg" == "$cfg_name" ]]; then
                            rm -f "$HOME/.config/$rel_cfg"
                        fi
                    done
                elif [[ "$file" == compositors/* || "$file" == compositor/* ]]; then
                    local comp_part="${file#compositor*/}"
                    local comp_name="${comp_part%%/*}"
                    local comp_file="${comp_part#*/}"
                    for comp in "${COMPOSITORS[@]}"; do
                        if [[ "$comp" == "$comp_name" ]]; then
                            local target_config_name
                            case "$comp" in
                                hyprland) target_config_name="hypr" ;;
                                niri) target_config_name="niri" ;;
                                sway) target_config_name="sway" ;;
                                *) target_config_name="$comp" ;;
                            esac
                            if [[ "$is_update" == true && ( "$comp_file" == *"monitors"* || "$comp_file" == *"output"* ) ]]; then
                                continue
                            fi
                            rm -f "$HOME/.config/$target_config_name/$comp_file"
                        fi
                    done
                fi
            done <<< "$deleted_files"
        fi

        if [ -n "$changed_files" ]; then
            while IFS= read -r file; do
                [[ -z "$file" ]] && continue
                if [[ "$file" == bin/* ]]; then
                    mkdir -p "$(dirname "$TARGET_BASE/$file")"
                    cp "$REPO_ROOT/$file" "$TARGET_BASE/$file"
                    chmod +x "$TARGET_BASE/$file" 2>/dev/null || true
                elif [[ "$file" == src/* ]]; then
                    mkdir -p "$(dirname "$TARGET_BASE/$file")"
                    cp "$REPO_ROOT/$file" "$TARGET_BASE/$file"
                    if [[ "$file" == *.sh ]]; then
                        chmod +x "$TARGET_BASE/$file" 2>/dev/null || true
                    fi
                elif [[ "$file" == config/* ]]; then
                    local rel_cfg="${file#config/}"
                    local cfg_name="${rel_cfg%%/*}"
                    for cfg in "${EXTRA_CONFIGS[@]}"; do
                        if [[ "$cfg" == "$cfg_name" ]]; then
                            mkdir -p "$(dirname "$HOME/.config/$rel_cfg")"
                            cp "$REPO_ROOT/$file" "$HOME/.config/$rel_cfg"
                        fi
                    done
                elif [[ "$file" == compositors/* || "$file" == compositor/* ]]; then
                    local comp_part="${file#compositor*/}"
                    local comp_name="${comp_part%%/*}"
                    local comp_file="${comp_part#*/}"
                    for comp in "${COMPOSITORS[@]}"; do
                        if [[ "$comp" == "$comp_name" ]]; then
                            local target_config_name
                            case "$comp" in
                                hyprland) target_config_name="hypr" ;;
                                niri) target_config_name="niri" ;;
                                sway) target_config_name="sway" ;;
                                *) target_config_name="$comp" ;;
                            esac
                            if [[ "$is_update" == true && ( "$comp_file" == *"monitors"* || "$comp_file" == *"output"* ) && -f "$HOME/.config/$target_config_name/$comp_file" ]]; then
                                continue
                            fi
                            mkdir -p "$(dirname "$HOME/.config/$target_config_name/$comp_file")"
                            cp "$REPO_ROOT/$file" "$HOME/.config/$target_config_name/$comp_file"
                        fi
                    done
                fi
            done <<< "$changed_files"
        fi

        if [ -f "$REPO_ROOT/version.txt" ]; then
            cp "$REPO_ROOT/version.txt" "$TARGET_BASE/" 2>/dev/null || true
            cp "$REPO_ROOT/version.txt" "$TARGET_BASE/src/" 2>/dev/null || true
        fi
    fi


    if [ -f "$TARGET_BASE/bin/atlantic" ]; then
        ln -sf "$TARGET_BASE/bin/atlantic" "$BIN_DIR/atlantic"
        sudo ln -sf "$TARGET_BASE/bin/atlantic" /usr/local/bin/atlantic 2>/dev/null || true
    fi

    if [ -f "$TARGET_BASE/bin/atlanticd" ]; then
        ln -sf "$TARGET_BASE/bin/atlanticd" "$BIN_DIR/atlanticd"
        sudo ln -sf "$TARGET_BASE/bin/atlanticd" /usr/local/bin/atlanticd 2>/dev/null || true
    fi
}

