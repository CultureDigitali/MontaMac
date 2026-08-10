#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$ROOT_DIR/MontaMac.app"
RESOURCE_BUNDLE="$BIN_DIR/MontaMac_MontaMac.bundle"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
/bin/rm -rf "$APP_DIR/MontaMac_MontaMac.bundle"
cp "$BIN_DIR/MontaMac" "$APP_DIR/Contents/MacOS/MontaMac"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$RESOURCE_BUNDLE/MontaMac-logo.png" "$APP_DIR/Contents/Resources/MontaMac-logo.png"
for LANGUAGE in it en fr es; do
    /usr/bin/ditto "$RESOURCE_BUNDLE/$LANGUAGE.lproj" "$APP_DIR/Contents/Resources/$LANGUAGE.lproj"
done
SIGN_IDENTITY="${MONTAMAC_SIGN_IDENTITY:--}"
CODESIGN_ARGS=(--force --deep --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    CODESIGN_ARGS+=(--timestamp)
fi
codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
echo "Creato: $APP_DIR"
