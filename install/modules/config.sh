CONFIG_DIR="$HOME/.config/atlantic"
CONFIG_FILE="$CONFIG_DIR/settings.json"

init_atlantic_config() {
    local project_root="$1"
    local wallpaper_dir="$2"
    local install_state="$3"
    local is_reinstall="$4"
    local template_json="$project_root/config/atlantic/settings.json"
    local script_path="$project_root/src/scripts/location.sh"

    if [[ "$install_state" == "current" && "$is_reinstall" != "true" ]]; then
        return 0
    fi

    mkdir -p "$CONFIG_DIR"

    if [ -f "$template_json" ]; then
        if [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
            local merged_json
            merged_json=$(jq -s --arg wp "$wallpaper_dir" '
                (.[0] * .[1]) * (if ($wp | length > 0) then {wallpaperDir: $wp} else {} end)
            ' "$template_json" "$CONFIG_FILE" 2>/dev/null || true)
            if [ -n "$merged_json" ]; then
                echo "$merged_json" > "$CONFIG_FILE"
            fi
        else
            local initial_json
            initial_json=$(jq --arg wp "$wallpaper_dir" '
                . * (if ($wp | length > 0) then {wallpaperDir: $wp} else {} end)
            ' "$template_json" 2>/dev/null || true)
            if [ -n "$initial_json" ]; then
                echo "$initial_json" > "$CONFIG_FILE"
            else
                cp "$template_json" "$CONFIG_FILE"
            fi
        fi
    elif [ ! -f "$CONFIG_FILE" ]; then
        if [ -n "$wallpaper_dir" ]; then
            echo "{\"wallpaperDir\": \"$wallpaper_dir\"}" > "$CONFIG_FILE"
        else
            echo "{}" > "$CONFIG_FILE"
        fi
    fi

    if [[ "$is_reinstall" == "true" || "$install_state" == "fresh" || "$install_state" == "legacy" ]]; then
        if [ -f "$script_path" ]; then
            bash "$script_path" --refresh >/dev/null 2>&1 || true
        elif [ -f "$HOME/.local/share/atlantic/src/scripts/location.sh" ]; then
            bash "$HOME/.local/share/atlantic/src/scripts/location.sh" --refresh >/dev/null 2>&1 || true
        fi
        mkdir -p "$HOME/.cache/atlantic" 2>/dev/null || true
        echo "tr" > "$HOME/.cache/atlantic/current_layout.txt" 2>/dev/null || true
    fi

    # Hide unwanted applications from the launcher
    local hide_apps=(
        "bssh.desktop"
        "bvnc.desktop"
        "avahi-discover.desktop"
        "lstopo.desktop"
        "qv4l2.desktop"
        "qvidcap.desktop"
        "qt5ct.desktop"
        "qt6ct.desktop"
    )
    mkdir -p "$HOME/.local/share/applications" || true
    for app in "${hide_apps[@]}"; do
        if [ -f "/usr/share/applications/$app" ]; then
            cp "/usr/share/applications/$app" "$HOME/.local/share/applications/" 2>/dev/null || true
            if ! grep -q "^NoDisplay=true" "$HOME/.local/share/applications/$app" 2>/dev/null; then
                echo "NoDisplay=true" >> "$HOME/.local/share/applications/$app" 2>/dev/null || true
            fi
        fi
    done
}
