#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
GODOT_BIN="${GODOT:-godot}"

# Run inside the project context so Godot resolves autoload singleton names.
"$GODOT_BIN" --headless --path . --script res://tests/parse_all_scripts.gd
