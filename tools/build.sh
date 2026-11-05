#!/usr/bin/env bash
# Build desktop release Windows + Linux. Requires Godot 4.7 and matching export templates.
# Usage: GODOT=/path/to/godot tools/build.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1 && [[ ! -x "$GODOT" ]]; then
    echo "ERROR: Godot executable was not found: $GODOT" >&2
    exit 127
fi
GODOT_VERSION="$("$GODOT" --version 2>&1)"
if [[ ! "$GODOT_VERSION" =~ ^4\.7(\.|$) ]]; then
    echo "ERROR: Hold the Keep requires Godot 4.7; detected: $GODOT_VERSION" >&2
    exit 2
fi
cd "$(dirname "$0")/.."
mkdir -p build/windows build/linux
"$GODOT" --headless --import
"$GODOT" --headless --export-release "Windows Desktop" build/windows/HoldTheKeep.exe
"$GODOT" --headless --export-release "Linux" build/linux/HoldTheKeep.x86_64
for artifact in build/windows/HoldTheKeep.exe build/linux/HoldTheKeep.x86_64; do
    if [[ ! -s "$artifact" ]]; then
        echo "ERROR: Export did not produce a non-empty artifact: $artifact" >&2
        exit 1
    fi
done
echo "Selesai: build/windows/HoldTheKeep.exe  build/linux/HoldTheKeep.x86_64"
