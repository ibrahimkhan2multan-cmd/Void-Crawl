#!/usr/bin/env bash
# Installs pinned Godot + export templates + Android SDK packages on a GitHub runner.
# Never prints secrets. Usage: tools/ci/setup_godot.sh
set -euo pipefail
GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}"
TOOLS="${RUNNER_TEMP:-/tmp}/godot-tools"
mkdir -p "$TOOLS"

if [ ! -x "$TOOLS/godot" ]; then
  curl -fsSL --retry 4 -o "$TOOLS/godot.zip" "$BASE/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  unzip -q -o "$TOOLS/godot.zip" -d "$TOOLS"
  mv "$TOOLS/Godot_v${GODOT_VERSION}_linux.x86_64" "$TOOLS/godot"
  chmod +x "$TOOLS/godot"
fi
echo "$TOOLS" >> "$GITHUB_PATH"
export PATH="$TOOLS:$PATH"
godot --version

TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION%-stable}.stable"
if [ ! -f "$TPL_DIR/android_debug.apk" ]; then
  mkdir -p "$TPL_DIR"
  curl -fsSL --retry 4 -o "$TOOLS/templates.tpz" "$BASE/Godot_v${GODOT_VERSION}_export_templates.tpz"
  unzip -q -o "$TOOLS/templates.tpz" -d "$TOOLS/tpl"
  cp -r "$TOOLS"/tpl/templates/* "$TPL_DIR/"
  rm -rf "$TOOLS/tpl" "$TOOLS/templates.tpz"
fi
ls "$TPL_DIR" | grep -i android

# Android SDK (runner image ships one; make sure the packages Godot 4.7 wants exist)
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
SDKM="$(command -v sdkmanager || true)"
[ -z "$SDKM" ] && SDKM="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKM" --licenses >/dev/null 2>&1 || true
"$SDKM" "platform-tools" "build-tools;35.0.1" "platforms;android-35" "cmake;3.10.2.4988404" "ndk;28.1.13356709" >/dev/null
echo "ANDROID_HOME=$ANDROID_HOME" >> "$GITHUB_ENV"

# Editor settings so headless export can find the SDK and JDK
mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-4.7.tres" <<TRES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
export/android/java_sdk_path = "${JAVA_HOME}"
TRES
