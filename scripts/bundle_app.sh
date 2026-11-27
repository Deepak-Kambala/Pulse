#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/pulse-modcache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-/tmp/pulse-swiftcache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"

PLUGIN_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"

echo "Building Pulse (release)..."
swift build -c release --disable-sandbox -Xswiftc -plugin-path -Xswiftc "$PLUGIN_PATH"

BIN_PATH="$(swift build -c release --disable-sandbox -Xswiftc -plugin-path -Xswiftc "$PLUGIN_PATH" --show-bin-path)/Pulse"
APP_DIR="$ROOT_DIR/build/Pulse.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/Pulse"
cp "$ROOT_DIR/Pulse/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Pulse/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Pulse/Resources/PulseLogo.png" "$APP_DIR/Contents/Resources/PulseLogo.png"
cp "$ROOT_DIR/Pulse/Resources/max.mp3" "$APP_DIR/Contents/Resources/max.mp3"
cp "$ROOT_DIR/Pulse/Resources/low.mp3" "$APP_DIR/Contents/Resources/low.mp3"

# Ad-hoc sign so macOS Gatekeeper / notifications / LaunchServices treat it cleanly
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "Built: $APP_DIR"
