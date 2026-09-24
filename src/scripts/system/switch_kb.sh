#!/usr/bin/env bash
# switch_kb.sh <layout> [variant]
LAYOUT="${1:-tr}"
VARIANT="${2:-}"

LAYOUT="${LAYOUT,,}"
VARIANT="${VARIANT,,}"

# 1. Hyprland dynamic switch
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland &>/dev/null; then
    if [ -n "$VARIANT" ]; then
        hyprctl keyword input:kb_layout "$LAYOUT" >/dev/null 2>&1
        hyprctl keyword input:kb_variant "$VARIANT" >/dev/null 2>&1
    else
        hyprctl keyword input:kb_layout "$LAYOUT" >/dev/null 2>&1
        hyprctl keyword input:kb_variant "" >/dev/null 2>&1
    fi

    # Switch all detected keyboards
    KB_NAMES=$(hyprctl devices -j 2>/dev/null | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
    for kb in $KB_NAMES; do
        hyprctl switchxkblayout "$kb" 0 >/dev/null 2>&1 || true
    done

    # Persist in hyprland config if exists
    for conf in "$HOME/.config/hypr/hyprland.conf" "$HOME/.config/hypr/input.conf"; do
        if [ -f "$conf" ]; then
            if grep -q "kb_layout" "$conf"; then
                sed -i -E "s/^[[:space:]]*kb_layout[[:space:]]*=[[:space:]]*.*/    kb_layout = $LAYOUT/" "$conf"
                if [ -n "$VARIANT" ]; then
                    if grep -q "kb_variant" "$conf"; then
                        sed -i -E "s/^[[:space:]]*kb_variant[[:space:]]*=[[:space:]]*.*/    kb_variant = $VARIANT/" "$conf"
                    fi
                else
                    if grep -q "kb_variant" "$conf"; then
                        sed -i -E "s/^[[:space:]]*kb_variant[[:space:]]*=[[:space:]]*.*/    kb_variant =/" "$conf"
                    fi
                fi
            fi
        fi
    done
elif [ -n "$NIRI_SOCKET" ] || pgrep -x niri &>/dev/null; then
    niri msg action switch-layout "$LAYOUT" 2>/dev/null || true
elif [ -n "$SWAYSOCK" ] || pgrep -x sway &>/dev/null; then
    swaymsg input "type:keyboard" xkb_layout "$LAYOUT" 2>/dev/null || true
fi

# 2. XWayland / X11 fallback
if command -v setxkbmap &>/dev/null; then
    if [ -n "$VARIANT" ]; then
        setxkbmap "$LAYOUT" -variant "$VARIANT" 2>/dev/null || true
    else
        setxkbmap "$LAYOUT" 2>/dev/null || true
    fi
fi
