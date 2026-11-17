#!/usr/bin/env bash
# Package a built Inlet.app into the release artifacts:
#   Inlet-<version>.zip   the app, for Sparkle and manual download
#   Inlet-<version>.dmg   drag-to-Applications disk image
#   SHA256SUMS.txt       checksums for both
#
# Usage: scripts/release/package.sh <path/to/Inlet.app> <version> <out-dir>
#
# Signing happens in the release workflow before this script runs: Developer ID when the
# signing secrets are set, ad-hoc otherwise. See "Signing and notarization" in RELEASING.md.

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <path/to/Inlet.app> <version> <out-dir>" >&2
  exit 2
fi

APP="$1"
VERSION="$2"
OUT="$3"
NAME="Inlet-${VERSION}"

if [ ! -d "$APP" ]; then
  echo "error: app bundle not found at $APP" >&2
  exit 1
fi

# Fail early if the bundle's signature is broken. An ad-hoc signature must still verify.
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$OUT"
rm -f "$OUT/$NAME.zip" "$OUT/$NAME.dmg" "$OUT/SHA256SUMS.txt"

# Zip with ditto, not zip: it keeps the bundle's resource forks, signature and symlinks intact.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME.zip"

# DMG: the app plus an /Applications alias so people can drag it across.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/Inlet.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "Inlet ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$OUT/$NAME.dmg" >/dev/null

# Stable-named copy so https://github.com/FreezingShock/Inlet/releases/latest/download/Inlet.dmg
# always points at the newest release. The versioned file stays for archives.
cp "$OUT/$NAME.dmg" "$OUT/Inlet.dmg"

(
  cd "$OUT"
  shasum -a 256 "$NAME.zip" "$NAME.dmg" Inlet.dmg > SHA256SUMS.txt
)

echo "Packaged:"
ls -lh "$OUT/$NAME.zip" "$OUT/$NAME.dmg" "$OUT/SHA256SUMS.txt"
