#!/usr/bin/env bash

# Warp logic wrapper for NetworkPopup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARP_SH="$SCRIPT_DIR/../../scripts/warp.sh"

if [[ -f "$WARP_SH" ]]; then
    bash "$WARP_SH" "$@"
else
    # Fallback status if warp.sh not found
    echo '{"installed":false,"connected":false,"status":"Disconnected","ip":"No IP","isp":"Unknown","colo":"IST","mode":"WARP","ping":"--"}'
fi
