#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GODOT_BIN="${GODOT:-godot}"
GODOT_VERSION="$("$GODOT_BIN" --version)"
if [[ ! "$GODOT_VERSION" =~ ^4\.7([.]|$) ]]; then
    echo "Expected Godot 4.7, got: $GODOT_VERSION" >&2
    exit 1
fi

TEMPLATE_DIR="$ROOT_DIR/build/android"
TEMPLATE_PATH="$TEMPLATE_DIR/android_debug.perfetto.apk"
APK_PATH="$TEMPLATE_DIR/HoldTheKeep-armv7-debug.apk"
TEMPLATE_URL="${GODOT_ANDROID_DEBUG_TEMPLATE_URL:-https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_android_debug.perfetto.apk}"

mkdir -p "$TEMPLATE_DIR"
if [[ ! -s "$TEMPLATE_PATH" ]]; then
    echo "Downloading the matching Godot 4.7 Android debug export template..."
    curl --fail --location --retry 3 --output "$TEMPLATE_PATH" "$TEMPLATE_URL"
fi

unzip -tq "$TEMPLATE_PATH" >/dev/null
"$GODOT_BIN" --headless --path . --import
"$GODOT_BIN" --headless --path . --export-debug "Android ARMv7 Debug" "$APK_PATH"

if [[ ! -s "$APK_PATH" ]]; then
    echo "Android export did not produce an APK: $APK_PATH" >&2
    exit 1
fi

ABI_LIST="$(unzip -Z1 "$APK_PATH" | awk -F/ '$1 == "lib" && $3 ~ /[.]so$/ { print $2 }' | sort -u)"
if [[ "$ABI_LIST" != "armeabi-v7a" ]]; then
    echo "Expected an ARMv7-only APK, found ABI entries: ${ABI_LIST:-none}" >&2
    exit 1
fi

sha256sum "$APK_PATH"
echo "PASS: exported ARMv7-only Android debug APK: $APK_PATH"
