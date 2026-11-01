#!/usr/bin/env bash
# scripts/package-dmg.sh — build the app, then produce an unsigned DMG and ZIP.
#
# Usage: bash scripts/package-dmg.sh [version] [build-number]
#
# No code signing, notarization or stapling is performed anywhere.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-}"
BUILD_NUMBER="${2:-}"

echo "==> Assembling SakuraSwitch.app"
bash "$SCRIPT_DIR/build-app.sh" "$VERSION" "$BUILD_NUMBER"

if [[ -z "$VERSION" ]]; then
  if [[ -f VERSION ]]; then
    VERSION="$(tr -d '[:space:]' < VERSION)"
  else
    VERSION="0.0.0-dev"
  fi
fi

DMG_PATH="build/SakuraSwitch.dmg"
ZIP_PATH="build/SakuraSwitch.zip"

echo "==> Creating DMG"
rm -f "$DMG_PATH"
hdiutil create -volname "Sakura Switch" \
  -srcfolder build/SakuraSwitch.app \
  -ov -format UDZO "$DMG_PATH" | tail -1

echo "==> Creating ZIP"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent build/SakuraSwitch.app "$ZIP_PATH"

echo "==> Artifacts:"
for f in "$DMG_PATH" "$ZIP_PATH" build/SakuraSwitch.app; do
  if [[ -e "$f" ]]; then
    printf '  %-28s %s\n' "$f" "$(du -sh "$f" | awk '{print $1}')"
  fi
done
