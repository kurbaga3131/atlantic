#!/usr/bin/env bash

# Cloudflare WARP helper script for Atlantic
# Provides JSON status and controls for WARP VPN

ACTION="${1:-status}"
CACHE_FILE="${XDG_RUNTIME_DIR:-/tmp}/atlantic_warp_cache.json"
CACHE_TTL=15

ensure_warp_registered() {
    if ! command -v warp-cli &>/dev/null; then
        return 1
    fi

    if command -v systemctl &>/dev/null; then
        if ! systemctl is-active --quiet systemd-resolved.service 2>/dev/null; then
            sudo systemctl enable --now systemd-resolved.service 2>/dev/null || true
            sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
        fi
        if ! systemctl is-active --quiet warp-svc.service 2>/dev/null; then
            sudo systemctl start warp-svc.service 2>/dev/null || true
            sleep 1
        fi
    fi

    if warp-cli registration show >/dev/null 2>&1; then
        warp-cli tunnel protocol set MASQUE >/dev/null 2>&1 || true
        return 0
    fi

    # Try modern warp-cli v2024+ syntax first, then legacy
    warp-cli registration new >/dev/null 2>&1 || \
    warp-cli --accept-tos registration new >/dev/null 2>&1 || \
    warp-cli register >/dev/null 2>&1 || true

    warp-cli mode warp >/dev/null 2>&1 || true
    warp-cli tunnel protocol set MASQUE >/dev/null 2>&1 || true
    warp-cli disconnect >/dev/null 2>&1 || true
}

get_warp_cli_status() {
    if ! command -v warp-cli &>/dev/null; then
        echo "not_installed"
        return
    fi
    local raw
    raw=$(warp-cli status 2>&1 || true)
    if [[ -z "$raw" ]] || echo "$raw" | grep -qiE "missing|register|error|daemon|socket"; then
        ensure_warp_registered
        raw=$(warp-cli status 2>&1 || true)
    fi

    if echo "$raw" | grep -qi "connecting"; then
        echo "connecting"
    elif echo "$raw" | grep -qi "connected" && ! echo "$raw" | grep -qi "disconnected"; then
        echo "connected"
    else
        echo "disconnected"
    fi
}

fetch_network_details() {
    local is_conn="$1"
    local ip=""
    local isp=""
    local colo=""
    local ping_val=""

    # Try ip-api.com first (provides both IP and ISP like Türk Telekom)
    local ip_json
    ip_json=$(curl -s --max-time 1.5 "http://ip-api.com/json" 2>/dev/null || true)
    if [[ -n "$ip_json" ]] && command -v jq &>/dev/null; then
        ip=$(echo "$ip_json" | jq -r '.query // empty' 2>/dev/null || true)
        isp=$(echo "$ip_json" | jq -r '.isp // .org // empty' 2>/dev/null || true)
        colo=$(echo "$ip_json" | jq -r '.city // empty' 2>/dev/null || true)
    fi

    # Fallback to Cloudflare trace if IP or colo missing
    if [[ -z "$ip" || -z "$colo" ]]; then
        local trace
        trace=$(curl -s --max-time 1.5 "https://1.1.1.1/cdn-cgi/trace" 2>/dev/null || true)
        if [[ -n "$trace" ]]; then
            [[ -z "$ip" ]] && ip=$(echo "$trace" | grep '^ip=' | cut -d'=' -f2)
            [[ -z "$colo" ]] && colo=$(echo "$trace" | grep '^colo=' | cut -d'=' -f2)
        fi
    fi

    # Fallback to local default route IP if still empty
    if [[ -z "$ip" ]]; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    fi

    if [[ -z "$isp" ]]; then
        if [[ "$is_conn" == "true" ]]; then
            isp="Cloudflare, Inc."
        else
            isp="Local Network"
        fi
    fi

    # Measure ping to 1.1.1.1
    if command -v ping &>/dev/null; then
        ping_val=$(ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F'/' 'END{if ($5) printf "%.0f ms", $5}')
    fi
    [[ -z "$ping_val" ]] && ping_val="12 ms"

    echo "$ip|$isp|$colo|$ping_val"
}

output_status() {
    local state
    state=$(get_warp_cli_status)

    if [[ "$state" == "not_installed" ]]; then
        cat <<EOF
{
  "installed": false,
  "connected": false,
  "status": "Not Installed",
  "ip": "N/A",
  "isp": "N/A",
  "colo": "N/A",
  "mode": "WARP",
  "ping": "--"
}
EOF
        return
    fi

    local is_connected="false"
    local status_label="Disconnected"
    if [[ "$state" == "connected" ]]; then
        is_connected="true"
        status_label="Connected"
    elif [[ "$state" == "connecting" ]]; then
        status_label="Connecting"
    fi

    # Check cache if valid
    local now
    now=$(date +%s)
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_mtime
        cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        local diff=$(( now - cache_mtime ))
        if (( diff < CACHE_TTL )); then
            # Replace connected & status in cache with current state to avoid stale toggle
            if command -v jq &>/dev/null; then
                jq --arg c "$is_connected" --arg s "$status_label" \
                   '.connected = ($c == "true") | .status = $s' "$CACHE_FILE" 2>/dev/null && return
            fi
        fi
    fi

    # Fetch fresh network details
    local details
    details=$(fetch_network_details "$is_connected")
    local ip isp colo ping_val
    IFS='|' read -r ip isp colo ping_val <<< "$details"

    [[ -z "$ip" ]] && ip="No IP"
    [[ -z "$colo" ]] && colo="IST"
    local mode="1.1.1.1 + WARP"
    if [[ "$is_connected" != "true" ]]; then
        mode="Direct (No WARP)"
    fi

    cat <<EOF > "$CACHE_FILE"
{
  "installed": true,
  "connected": $is_connected,
  "status": "$status_label",
  "ip": "$ip",
  "isp": "$isp",
  "colo": "$colo",
  "mode": "$mode",
  "ping": "$ping_val"
}
EOF
    cat "$CACHE_FILE"
}

case "$ACTION" in
    connect)
        rm -f "$CACHE_FILE"
        warp-cli connect >/dev/null 2>&1 || true
        sleep 0.5
        output_status
        ;;
    disconnect)
        rm -f "$CACHE_FILE"
        warp-cli disconnect >/dev/null 2>&1 || true
        sleep 0.3
        output_status
        ;;
    toggle)
        rm -f "$CACHE_FILE"
        state=$(get_warp_cli_status)
        if [[ "$state" == "connected" ]]; then
            warp-cli disconnect >/dev/null 2>&1 || true
        else
            warp-cli connect >/dev/null 2>&1 || true
        fi
        sleep 0.5
        output_status
        ;;
    status|*)
        output_status
        ;;
esac
