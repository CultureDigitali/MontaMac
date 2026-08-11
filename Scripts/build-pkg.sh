#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DIST_DIR="$ROOT_DIR/dist"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Resources/Info.plist")"
STAGING_DIR="$(mktemp -d /private/tmp/montamac-pkg.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

if [[ "${MONTAMAC_RELEASE_BUILD:-0}" == "1" && -z "${MONTAMAC_INSTALLER_IDENTITY:-}" ]]; then
  echo "Errore release: manca MONTAMAC_INSTALLER_IDENTITY." >&2
  exit 1
fi
zsh "$ROOT_DIR/Scripts/build-app.sh"
mkdir -p "$STAGING_DIR/Applications" "$DIST_DIR"
ditto --norsrc --noextattr --noqtn --noacl "$ROOT_DIR/MontaMac.app" "$STAGING_DIR/Applications/MontaMac.app"

PKGBUILD_ARGS=(
  --root "$STAGING_DIR"
  --identifier "local.montamac.app"
  --version "$APP_VERSION"
  --scripts "$ROOT_DIR/Installer/scripts"
)
if [[ -n "${MONTAMAC_INSTALLER_IDENTITY:-}" ]]; then
  PKGBUILD_ARGS+=(--sign "$MONTAMAC_INSTALLER_IDENTITY")
fi
pkgbuild "${PKGBUILD_ARGS[@]}" "$DIST_DIR/MontaMac-$APP_VERSION.pkg"

echo "Creato: $DIST_DIR/MontaMac-$APP_VERSION.pkg"
