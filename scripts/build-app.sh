#!/usr/bin/env bash
# scripts/build-app.sh — assemble SakuraSwitch.app from the SwiftPM build product.
#
# Usage: bash scripts/build-app.sh [version] [build-number]
#   version defaults to the contents of the VERSION file, or 0.0.0-dev.
#   build-number defaults to a timestamp.
#
# CODE_SIGN_IDENTITY defaults to ad-hoc signing (-). Set it to a persistent
# signing identity to preserve TCC grants across rebuilds.

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

ensure_app_is_not_running() {
  local pid running_path
  while IFS= read -r pid; do
    running_path="$(ps -p "$pid" -o comm= 2>/dev/null || true)"
    if [[ "$running_path" == "$ROOT_DIR/$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME" ]]; then
      echo "error: $APP_NAME is running from $APP_DIR (PID $pid)." >&2
      echo "Quit that app before packaging. Replacing a running app invalidates its code identity and can break TCC permission checks." >&2
      exit 1
    fi
  done < <(pgrep -x "$EXECUTABLE_NAME" || true)
}

ensure_app_is_not_running

echo "==> Building $APP_NAME $VERSION (build $BUILD_NUMBER)"

# ------------------------------------------------------------------ build ----
# Prefer a universal binary; fall back to the host architecture.
UNIVERSAL_ARGS=(--arch arm64 --arch x86_64)
BIN_PATH=""
if swift build -c release "${UNIVERSAL_ARGS[@]}"; then
  BIN_PATH="$(swift build -c release "${UNIVERSAL_ARGS[@]}" --show-bin-path)/SakuraSwitch"
  echo "==> Universal binary (arm64 + x86_64)"
else
  echo "==> Universal build failed, falling back to host architecture" >&2
  swift build -c release
  BIN_PATH="$(swift build -c release --show-bin-path)/SakuraSwitch"
fi

if [[ -z "$BIN_PATH" || ! -f "$BIN_PATH" ]]; then
  echo "error: could not locate the SakuraSwitch build product" >&2
  exit 1
fi

# ----------------------------------------------------------------- bundle ----
# The user may have launched the app while compilation was in progress.
ensure_app_is_not_running
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

# The linker's signature covers only the executable, not the assembled app.
# TCC needs a valid bundle signature that binds its identifier and Info.plist.
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
codesign --force --sign "$CODE_SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_DIR"
codesign --verify --strict --all-architectures --verbose=2 "$APP_DIR"

echo "==> Built $APP_DIR"
file "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
du -sh "$APP_DIR" | awk '{print "==> Size: " $1}'
