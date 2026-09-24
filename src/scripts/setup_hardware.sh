#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PYTHON_BIN=""

if command -v python3 &>/dev/null; then
    PYTHON_BIN="python3"
elif command -v python &>/dev/null; then
    PYTHON_BIN="python"
fi

if [ -n "$PYTHON_BIN" ] && [ -f "$SCRIPT_DIR/setup_hardware.py" ]; then
    exec "$PYTHON_BIN" "$SCRIPT_DIR/setup_hardware.py" "$@"
fi
