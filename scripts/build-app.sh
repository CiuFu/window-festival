#!/bin/zsh
# Package the knit border daemon as a proper menu bar app bundle.
# LSUIElement keeps it out of the Dock. Ad-hoc signing verifies the local
# bundle; it is not Developer ID signing or notarization for distribution.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/outputs/Window Festival.app"
STAGE="$(mktemp -d /tmp/window-festival-build.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

make -C "$ROOT" >/dev/null

STAGED="$STAGE/Window Festival.app/Contents"
mkdir -p "$STAGED/MacOS"
cp -f "$ROOT/bin/borders"     "$STAGED/MacOS/WindowFestival"
cp -f "$ROOT/AppInfo.plist"   "$STAGED/Info.plist"
mkdir -p "$STAGED/Resources" "$STAGE/AppIcon.iconset"
cp "$ROOT/LICENSE" "$ROOT/NOTICE.md" "$STAGED/Resources/"
clang -O2 -fobjc-arc -I"$ROOT/src" "$ROOT/scripts/build-icon.m" -framework Cocoa -o "$STAGE/build-icon"
"$STAGE/build-icon" "$STAGE/AppIcon.iconset"
iconutil -c icns "$STAGE/AppIcon.iconset" -o "$STAGED/Resources/AppIcon.icns"
chmod +x "$STAGED/MacOS/WindowFestival"

xattr -cr "$STAGE/Window Festival.app"
codesign --force --deep --sign - "$STAGE/Window Festival.app"
codesign --verify --deep --strict "$STAGE/Window Festival.app"

mkdir -p "$ROOT/outputs"
rm -rf "$APP"
ditto "$STAGE/Window Festival.app" "$APP"
echo "$APP"
