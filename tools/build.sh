#!/usr/bin/env bash
# Build rilis Windows + Linux. Butuh Godot 4.3 dan export template 4.3 terpasang.
# Pemakaian: GODOT=/path/ke/godot tools/build.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
mkdir -p build/windows build/linux
"$GODOT" --headless --import
"$GODOT" --headless --export-release "Windows Desktop" build/windows/HoldTheKeep.exe
"$GODOT" --headless --export-release "Linux" build/linux/HoldTheKeep.x86_64
echo "Selesai: build/windows/HoldTheKeep.exe  build/linux/HoldTheKeep.x86_64"
