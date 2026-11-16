#!/usr/bin/env bash
# Package a built Cove.app into the release artifacts:
#   Cove-<version>.zip   the app, for Sparkle and manual download
#   Cove-<version>.dmg   drag-to-Applications disk image
#   SHA256SUMS.txt       checksums for both
#
# Usage: scripts/release/package.sh <path/to/Cove.app> <version> <out-dir>
#
# Signing is ad-hoc for now. To add Developer ID signing and notarization,
# see the SIGNING HOOK section in RELEASING.md.

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <path/to/Cove.app> <version> <out-dir>" >&2
  exit 2
fi

APP="$1"
VERSION="$2"
OUT="$3"
NAME="Cove-${VERSION}"

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
cp -R "$APP" "$STAGE/Cove.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create \
  -volname "Cove ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$OUT/$NAME.dmg" >/dev/null

# Stable-named copy so https://github.com/FreezingShock/Cove/releases/latest/download/Cove.dmg
# always points at the newest release. The versioned file stays for archives.
cp "$OUT/$NAME.dmg" "$OUT/Cove.dmg"

(
  cd "$OUT"
  shasum -a 256 "$NAME.zip" "$NAME.dmg" Cove.dmg > SHA256SUMS.txt
)

echo "Packaged:"
ls -lh "$OUT/$NAME.zip" "$OUT/$NAME.dmg" "$OUT/SHA256SUMS.txt"
