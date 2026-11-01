#!/usr/bin/env bash
# scripts/build-app.sh — assemble SakuraSwitch.app from the SwiftPM build product.
#
# Usage: bash scripts/build-app.sh [version] [build-number]
#   version defaults to the contents of the VERSION file, or 0.0.0-dev.
#   build-number defaults to a timestamp.
#
# No code signing is performed anywhere in this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# ---------------------------------------------------------------- version ----
VERSION="${1:-}"
BUILD_NUMBER="${2:-}"

if [[ -z "$VERSION" ]]; then
  if [[ -f VERSION ]]; then
    VERSION="$(tr -d '[:space:]' < VERSION)"
  else
    VERSION="0.0.0-dev"
  fi
fi
if [[ -z "$BUILD_NUMBER" ]]; then
  BUILD_NUMBER="$(date +%Y%m%d%H%M)"
fi

BUNDLE_ID="com.yueseqaz.sakuraswitch"
APP_NAME="Sakura Switch"
EXECUTABLE_NAME="SakuraSwitch"
APP_DIR="build/SakuraSwitch.app"

echo "==> Building $APP_NAME $VERSION (build $BUILD_NUMBER)"

# ------------------------------------------------------------------ build ----
# Prefer a universal binary; fall back to the host architecture.
UNIVERSAL_ARGS=(--arch arm64 --arch x86_64)
BIN_PATH=""
if swift build -c release "${UNIVERSAL_ARGS[@]}"; then
  # SwiftPM puts multi-arch products under .build/apple/.
  for candidate in .build/apple/Products/Release/SakuraSwitch .build/release/SakuraSwitch; do
    if [[ -f "$candidate" ]]; then BIN_PATH="$candidate"; break; fi
  done
  echo "==> Universal binary (arm64 + x86_64)"
else
  echo "==> Universal build failed, falling back to host architecture" >&2
  swift build -c release
  BIN_PATH=".build/release/SakuraSwitch"
fi

if [[ -z "$BIN_PATH" || ! -f "$BIN_PATH" ]]; then
  echo "error: could not locate the SakuraSwitch build product" >&2
  exit 1
fi

# ----------------------------------------------------------------- bundle ----
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"

if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
else
  echo "warning: Resources/AppIcon.icns not found; the app will have no icon" >&2
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$EXECUTABLE_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSUIElement</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>NSHumanReadableCopyright</key>
	<string>MIT License</string>
	<key>NSScreenCaptureUsageDescription</key>
	<string>Sakura Switch uses screen recording only to show live window thumbnails in the switcher. Without it, app icons are shown instead.</string>
</dict>
</plist>
PLIST

plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null

echo "==> Built $APP_DIR"
file "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
du -sh "$APP_DIR" | awk '{print "==> Size: " $1}'
