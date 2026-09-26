#!/usr/bin/env bash
# ==============================================================================
# Atlantic Cyberpunk Zerene Dashboard Launcher
# Launches a 4-pane electric-blue cyberpunk workstation layout:
#   Top-Left:     Fastfetch with Zerene Propeller Logo & System Info
#   Bottom-Left:  Cava Audio Visualizer with electric blue gradient
#   Top-Right:    Btop / System Telemetry Monitor
#   Bottom-Right: Interactive Shell Terminal
# Each window is independent and can be closed individually with Alt+F4!
# ==============================================================================

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
ATLANTIC_DIR="$(dirname "$SCRIPT_DIR")"

# If dashboard windows are already open, just launch a standard terminal
if pgrep -f "cyber_cava" >/dev/null 2>&1 || pgrep -f "cyber_fastfetch" >/dev/null 2>&1; then
    kitty &
    exit 0
fi

# Detect system monitor tool
if command -v btop >/dev/null 2>&1; then
    MONITOR_CMD="btop"
elif command -v htop >/dev/null 2>&1; then
    MONITOR_CMD="htop"
else
    MONITOR_CMD="top"
fi

# Check for Hyprland session
IS_HYPRLAND=false
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || pgrep -x Hyprland >/dev/null 2>&1; then
    IS_HYPRLAND=true
fi

if [ "$IS_HYPRLAND" = true ]; then
    # 1. Launch Fastfetch (Top-Left)
    kitty --class "cyber_fastfetch" --title "zerene-info" -e bash -c "fastfetch; exec bash" &
    sleep 0.35

    # 2. Launch System Monitor (Top-Right)
    kitty --class "cyber_btop" --title "system-monitor" -e $MONITOR_CMD &
    sleep 0.35

    # 3. Focus Fastfetch on the left and preselect split down for Cava
    hyprctl dispatch focuswindow "class:cyber_fastfetch" >/dev/null 2>&1 || true
    hyprctl dispatch layoutmsg "preselect d" >/dev/null 2>&1 || true
    sleep 0.1
    kitty --class "cyber_cava" --title "audio-visualizer" -e cava &
    sleep 0.35

    # 4. Focus System Monitor on the right and preselect split down for Terminal
    hyprctl dispatch focuswindow "class:cyber_btop" >/dev/null 2>&1 || true
    hyprctl dispatch layoutmsg "preselect d" >/dev/null 2>&1 || true
    sleep 0.1
    kitty --class "cyber_term" --title "terminal" &
else
    # Fallback for generic wayland/X11 compositors
    kitty --class "cyber_fastfetch" --title "zerene-info" -e bash -c "fastfetch; exec bash" &
    sleep 0.2
    kitty --class "cyber_btop" --title "system-monitor" -e $MONITOR_CMD &
    sleep 0.2
    kitty --class "cyber_cava" --title "audio-visualizer" -e cava &
    sleep 0.2
    kitty --class "cyber_term" --title "terminal" &
fi
