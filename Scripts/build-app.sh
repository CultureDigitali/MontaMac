#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
cd "$ROOT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$ROOT_DIR/MontaMac.app"
RESOURCE_BUNDLE="$BIN_DIR/MontaMac_MontaMac.bundle"
SPARKLE_FRAMEWORK="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"
/bin/rm -rf "$APP_DIR/MontaMac_MontaMac.bundle"
/bin/rm -rf "$APP_DIR/Contents/Frameworks/Sparkle.framework"
cp "$BIN_DIR/MontaMac" "$APP_DIR/Contents/MacOS/MontaMac"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
/usr/bin/ditto "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
/usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/MontaMac" 2>/dev/null || true
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$RESOURCE_BUNDLE/MontaMac-logo.png" "$APP_DIR/Contents/Resources/MontaMac-logo.png"
for LANGUAGE in it en fr es; do
    /usr/bin/ditto "$RESOURCE_BUNDLE/$LANGUAGE.lproj" "$APP_DIR/Contents/Resources/$LANGUAGE.lproj"
done

FEED_URL="${MONTAMAC_SPARKLE_FEED_URL:-}"
PUBLIC_KEY="${MONTAMAC_SPARKLE_PUBLIC_KEY:-}"
if [[ -n "$FEED_URL" || -n "$PUBLIC_KEY" ]]; then
    if [[ -z "$FEED_URL" || -z "$PUBLIC_KEY" || "$FEED_URL" != https://* ]]; then
        echo "Errore: feed HTTPS e chiave pubblica Sparkle devono essere forniti insieme." >&2
        exit 1
    fi
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $FEED_URL" "$APP_DIR/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_KEY" "$APP_DIR/Contents/Info.plist"
fi

SIGN_IDENTITY="${MONTAMAC_SIGN_IDENTITY:--}"
CODESIGN_ARGS=(--force --deep --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
    CODESIGN_ARGS+=(--timestamp)
else
    CODESIGN_ARGS+=(--entitlements "$ROOT_DIR/Resources/MontaMac.local.entitlements")
fi
codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
echo "Creato: $APP_DIR"
