#!/usr/bin/env bash
# switch_kb.sh <layout> [variant]
LAYOUT="${1:-tr}"
VARIANT="${2:-}"

LAYOUT="${LAYOUT,,}"
VARIANT="${VARIANT,,}"

# Cache layout
mkdir -p "$HOME/.cache/atlantic" 2>/dev/null || true
if [ "$LAYOUT" == "tr" ] && [ "$VARIANT" == "f" ]; then
    echo "tr-f" > "$HOME/.cache/atlantic/current_layout.txt" 2>/dev/null || true
else
    echo "$LAYOUT" > "$HOME/.cache/atlantic/current_layout.txt" 2>/dev/null || true
fi

# 1. Hyprland dynamic switch
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland &>/dev/null; then
    if [ -n "$VARIANT" ]; then
        hyprctl keyword input:kb_layout "$LAYOUT" >/dev/null 2>&1 || true
        hyprctl keyword input:kb_variant "$VARIANT" >/dev/null 2>&1 || true
    else
        hyprctl keyword input:kb_layout "$LAYOUT" >/dev/null 2>&1 || true
        hyprctl keyword input:kb_variant "" >/dev/null 2>&1 || true
    fi

    # Switch all detected keyboards (per-device keywords and switchxkblayout)
    KB_NAMES=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[].name // empty' 2>/dev/null)
    if [ -z "$KB_NAMES" ]; then
        KB_NAMES=$(hyprctl devices -j 2>/dev/null | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
    fi
    while IFS= read -r kb; do
        [ -z "$kb" ] && continue
        hyprctl keyword "device:$kb:kb_layout" "$LAYOUT" >/dev/null 2>&1 || true
        hyprctl keyword "device[$kb]:kb_layout" "$LAYOUT" >/dev/null 2>&1 || true
        if [ -n "$VARIANT" ]; then
            hyprctl keyword "device:$kb:kb_variant" "$VARIANT" >/dev/null 2>&1 || true
            hyprctl keyword "device[$kb]:kb_variant" "$VARIANT" >/dev/null 2>&1 || true
        else
            hyprctl keyword "device:$kb:kb_variant" "" >/dev/null 2>&1 || true
            hyprctl keyword "device[$kb]:kb_variant" "" >/dev/null 2>&1 || true
        fi
        hyprctl switchxkblayout "$kb" 0 >/dev/null 2>&1 || true
    done <<< "$KB_NAMES"
    hyprctl switchxkblayout all 0 >/dev/null 2>&1 || true

    # Persist in Atlantic Hyprland Lua settings if exists
    for lua_conf in "$HOME/.config/hypr/config/settings.lua" "$HOME/.config/hypr/settings.lua"; do
        if [ -f "$lua_conf" ]; then
            sed -i -E 's/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*"[^"]*"/    kb_layout = "'"$LAYOUT"'"/' "$lua_conf" 2>/dev/null || true
            if [ -n "$VARIANT" ]; then
                if grep -q "kb_variant" "$lua_conf"; then
                    sed -i -E 's/^[[:space:]]*kb_variant[[:space:]]*=[[:space:]]*"[^"]*"/    kb_variant = "'"$VARIANT"'"/' "$lua_conf" 2>/dev/null || true
                else
                    sed -i -E '/kb_layout/a\    kb_variant = "'"$VARIANT"'",' "$lua_conf" 2>/dev/null || true
                fi
            else
                if grep -q "kb_variant" "$lua_conf"; then
                    sed -i -E 's/^[[:space:]]*kb_variant[[:space:]]*=[[:space:]]*"[^"]*"/    kb_variant = ""/' "$lua_conf" 2>/dev/null || true
                fi
            fi
        fi
    done

    # Persist in hyprland conf if exists
    for conf in "$HOME/.config/hypr/hyprland.conf" "$HOME/.config/hypr/input.conf"; do
        if [ -f "$conf" ]; then
            if grep -q "kb_layout" "$conf"; then
                sed -i -E "s/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*.*/    kb_layout = $LAYOUT/" "$conf" 2>/dev/null || true
                if [ -n "$VARIANT" ]; then
                    if grep -q "kb_variant" "$conf"; then
                        sed -i -E "s/^[[:space:]]*kb_variant[[:space:]]*=[[:space:]]*.*/    kb_variant = $VARIANT/" "$conf" 2>/dev/null || true
                    fi
                else
                    if grep -q "kb_variant" "$conf"; then
                        sed -i -E "s/^[[:space:]]*kb_variant[[:space:]]*=[[:space:]]*.*/    kb_variant =/" "$conf" 2>/dev/null || true
                    fi
                fi
            fi
        fi
    done

    # Reload hyprland to apply config changes to all devices cleanly
    hyprctl reload >/dev/null 2>&1 || true

elif [ -n "$NIRI_SOCKET" ] || pgrep -x niri &>/dev/null; then
    niri msg action switch-layout "$LAYOUT" 2>/dev/null || true
elif [ -n "$SWAYSOCK" ] || pgrep -x sway &>/dev/null; then
    swaymsg input "type:keyboard" xkb_layout "$LAYOUT" 2>/dev/null || true
    for conf in "$HOME/.config/sway/configDir/input" "$HOME/.config/sway/config"; do
        if [ -f "$conf" ] && grep -q "xkb_layout" "$conf"; then
            sed -i -E "s/^[[:space:]]*xkb_layout[[:space:]]*.*/    xkb_layout \"$LAYOUT\"/" "$conf" 2>/dev/null || true
        fi
    done
fi

# 2. XWayland / X11 fallback
if command -v setxkbmap &>/dev/null; then
    if [ -n "$VARIANT" ]; then
        setxkbmap -layout "$LAYOUT" -variant "$VARIANT" 2>/dev/null || true
    else
        setxkbmap -layout "$LAYOUT" 2>/dev/null || true
    fi
fi
