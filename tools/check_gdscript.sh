#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
GODOT_BIN="${GODOT:-godot}"

while IFS= read -r -d '' script; do
    resource_path="res://${script#./}"
    echo "::group::GDScript parse: ${resource_path}"
    "$GODOT_BIN" --headless --path . --check-only --script "$resource_path"
    echo "::endgroup::"
done < <(find scripts tests -type f -name '*.gd' -print0 | sort -z)

echo "PASS: all GDScript files parsed."
