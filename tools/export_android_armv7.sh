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

BUILD_DIR="$ROOT_DIR/build/android"
TEMPLATE_DIR="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/.local/share/godot/export_templates/4.7.stable}"
TEMPLATE_PATH="$TEMPLATE_DIR/android_debug.apk"
APK_PATH="$BUILD_DIR/HoldTheKeep-armv7-debug.apk"
TEMPLATE_URL="${GODOT_ANDROID_DEBUG_TEMPLATE_URL:-https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_android_debug.perfetto.apk}"

mkdir -p "$BUILD_DIR" "$TEMPLATE_DIR"
if [[ ! -s "$TEMPLATE_PATH" ]]; then
    TEMP_TEMPLATE="$BUILD_DIR/android_debug.perfetto.apk"
    echo "Downloading the matching Godot 4.7 Android debug export template..."
    curl --fail --location --retry 3 --output "$TEMP_TEMPLATE" "$TEMPLATE_URL"
    unzip -tq "$TEMP_TEMPLATE" >/dev/null
    install -m 0644 "$TEMP_TEMPLATE" "$TEMPLATE_PATH"
fi

unzip -tq "$TEMPLATE_PATH" >/dev/null
if [[ -z "${ANDROID_HOME:-}" ]]; then
    echo "ANDROID_HOME is not set. Install the Android SDK and export ANDROID_HOME." >&2
    exit 1
fi
if [[ -z "${JAVA_HOME:-}" ]]; then
    echo "JAVA_HOME is not set. Install JDK 17 and export JAVA_HOME." >&2
    exit 1
fi
if [[ ! -x "$ANDROID_HOME/platform-tools/adb" ]]; then
    echo "Android SDK platform-tools/adb is missing under $ANDROID_HOME." >&2
    exit 1
fi
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
