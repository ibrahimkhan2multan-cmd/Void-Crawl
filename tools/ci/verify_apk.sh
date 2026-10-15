#!/usr/bin/env bash
# Fails loudly unless the APK exists, is non-trivial, is a valid zip with the expected content and is signed.
set -euo pipefail
APK="${1:?apk path}"
[ -f "$APK" ] || { echo "::error::APK not found: $APK"; exit 1; }
SIZE=$(stat -c %s "$APK")
echo "APK size: $SIZE bytes"
[ "$SIZE" -gt 5000000 ] || { echo "::error::APK suspiciously small ($SIZE bytes)"; exit 1; }
unzip -tq "$APK" >/dev/null || { echo "::error::APK is not a valid zip"; exit 1; }
LIST=$(unzip -l "$APK")
echo "$LIST" | grep -q "AndroidManifest.xml" || { echo "::error::no AndroidManifest.xml"; exit 1; }
echo "$LIST" | grep -q "lib/arm64-v8a/libgodot_android.so" || { echo "::error::no arm64 engine library"; exit 1; }
echo "$LIST" | grep -qE "assets/.*\.(pck|zip)" || echo "(note: game data is embedded differently than assets/*.pck)"
APKSIGNER=$(ls "$ANDROID_HOME"/build-tools/35.0.1/apksigner)
"$APKSIGNER" verify --verbose "$APK" | head -5
echo "APK verified: $APK"
