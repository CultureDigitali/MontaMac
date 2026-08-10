#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$(mktemp -d /private/tmp/montamac-pkg.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

zsh "$ROOT_DIR/Scripts/build-app.sh"
mkdir -p "$STAGING_DIR/Applications" "$DIST_DIR"
ditto --norsrc --noextattr --noqtn --noacl "$ROOT_DIR/MontaMac.app" "$STAGING_DIR/Applications/MontaMac.app"

PKGBUILD_ARGS=(
  --root "$STAGING_DIR"
  --identifier "local.montamac.app"
  --version "2.1.0"
  --scripts "$ROOT_DIR/Installer/scripts"
)
if [[ -n "${MONTAMAC_INSTALLER_IDENTITY:-}" ]]; then
  PKGBUILD_ARGS+=(--sign "$MONTAMAC_INSTALLER_IDENTITY")
fi
pkgbuild "${PKGBUILD_ARGS[@]}" "$DIST_DIR/MontaMac-2.1.0.pkg"

echo "Creato: $DIST_DIR/MontaMac-2.1.0.pkg"
