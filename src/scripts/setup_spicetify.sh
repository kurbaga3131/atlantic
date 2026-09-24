#!/usr/bin/env bash

# Spicetify & Marketplace setup script for Atlantic
set -e

SPOTIFY_PATH="/opt/spotify"
TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6)
[[ -z "$USER_HOME" ]] && USER_HOME="$HOME"

# 1. Ensure write permissions for Spotify
if [ -d "$SPOTIFY_PATH" ]; then
    if [ "$EUID" -eq 0 ]; then
        chmod a+wr "$SPOTIFY_PATH" "$SPOTIFY_PATH/Apps" -R 2>/dev/null || true
    else
        sudo chmod a+wr "$SPOTIFY_PATH" "$SPOTIFY_PATH/Apps" -R 2>/dev/null || true
    fi
fi

# 2. Check if spicetify is installed
if ! command -v spicetify &>/dev/null; then
    exit 0
fi

# Run spicetify configuration and marketplace injection as the real user
run_as_user() {
    if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
        sudo -u "$SUDO_USER" -H bash -c "$1"
    else
        bash -c "$1"
    fi
}

run_as_user '
    SPICETIFY_DIR="$HOME/.config/spicetify"
    CUSTOM_APPS_DIR="$SPICETIFY_DIR/CustomApps"
    MARKETPLACE_DIR="$CUSTOM_APPS_DIR/marketplace"

    mkdir -p "$CUSTOM_APPS_DIR" "$SPICETIFY_DIR/Themes" "$SPICETIFY_DIR/Extensions"

    # Ensure Spotify configuration directory and prefs exist for first install
    mkdir -p "$HOME/.config/spotify"
    if [ ! -f "$HOME/.config/spotify/prefs" ]; then
        echo "app.autologin.enabled=false" > "$HOME/.config/spotify/prefs"
    fi

    # Configure paths
    spicetify config spotify_path "/opt/spotify" >/dev/null 2>&1 || true
    spicetify config prefs_path "$HOME/.config/spotify/prefs" >/dev/null 2>&1 || true

    # Link marketplace from system package if available
    if [ ! -d "$MARKETPLACE_DIR" ]; then
        if [ -d "/var/lib/spicetify-marketplace" ]; then
            cp -r /var/lib/spicetify-marketplace "$MARKETPLACE_DIR" 2>/dev/null || true
        elif [ -d "/usr/share/spicetify-marketplace" ]; then
            cp -r /usr/share/spicetify-marketplace "$MARKETPLACE_DIR" 2>/dev/null || true
        fi
    fi

    # If marketplace is still not installed, fetch it via official script
    if [ ! -d "$MARKETPLACE_DIR" ]; then
        curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.sh 2>/dev/null | sh >/dev/null 2>&1 || true
    fi

    # Enable marketplace custom app
    spicetify config custom_apps marketplace >/dev/null 2>&1 || true

    # Backup & Apply
    spicetify backup apply >/dev/null 2>&1 || spicetify apply >/dev/null 2>&1 || true
' || true
