#!/usr/bin/env bash
#
# Builds Inlet's Sparkle feed (appcast.xml) for one release.
#
# Called by the release workflow after it packages the app:
#   scripts/release/update-appcast.sh <version> <build> <zip-path> <out-dir>
#
#   <version>   marketing version, e.g. 0.2       (matches tag v0.2)
#   <build>     CFBundleVersion, e.g. 2           (Sparkle compares this number)
#   <zip-path>  the Inlet-<version>.zip the workflow built
#   <out-dir>   where appcast.xml is written; the workflow attaches it to the release
#
# Needs the environment variable SPARKLE_PRIVATE_KEY (the EdDSA private key,
# stored as a GitHub secret). The key is written to a temp file that is deleted
# on exit and is never printed.
#
# Requires: curl, tar with xz support, gh (for downloading the previous feed).

set -euo pipefail

SPARKLE_VERSION="2.10.1"   # keep in sync with the package version in Inlet.xcodeproj
REPO="FreezingShock/Inlet"

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <version> <build> <zip-path> <out-dir>" >&2
  exit 2
fi
version="$1"
build="$2"
zip_path="$3"
out_dir="$4"

: "${SPARKLE_PRIVATE_KEY:?SPARKLE_PRIVATE_KEY is not set (add it as a GitHub secret)}"
[[ -f "$zip_path" ]] || { echo "zip not found: $zip_path" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# 1. Check that the archive really holds this build number. A mismatch means the
#    feed would advertise the wrong version, so stop here.
archive_build="$(unzip -p "$zip_path" 'Inlet.app/Contents/Info.plist' \
  | plutil -extract CFBundleVersion raw -o - -)"
if [[ "$archive_build" != "$build" ]]; then
  echo "build mismatch: archive has CFBundleVersion $archive_build, expected $build" >&2
  exit 1
fi

# 2. Fetch Sparkle's command-line tools at the pinned version.
tools="$work/sparkle"
mkdir -p "$tools"
curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" \
  | tar -xJ -C "$tools"
generate_appcast="$tools/bin/generate_appcast"
[[ -x "$generate_appcast" ]] || { echo "generate_appcast not found in Sparkle tarball" >&2; exit 1; }

# 3. Stage the new archive in its own folder. generate_appcast reads every archive
#    in that folder, so only the release archive goes in.
stage="$work/updates"
mkdir -p "$stage" "$out_dir"
cp "$zip_path" "$stage/"

# 4. Start from the previous feed so older releases stay listed. The first release
#    has no previous feed, so a failed download is fine.
if gh release download --repo "$REPO" --pattern appcast.xml --dir "$stage" --clobber 2>/dev/null; then
  echo "Loaded previous appcast.xml from the latest release"
else
  echo "No previous appcast.xml found; starting a new feed"
fi

# 5. Write the private key to a file readable only by us.
key_file="$work/ed25519_private_key"
( umask 077; printf '%s' "$SPARKLE_PRIVATE_KEY" > "$key_file" )

# 6. Generate the feed. Each item's enclosure points at the release asset.
"$generate_appcast" \
  --ed-key-file "$key_file" \
  --download-url-prefix "https://github.com/${REPO}/releases/download/v${version}/" \
  "$stage"

cp "$stage/appcast.xml" "$out_dir/appcast.xml"
echo "Wrote $out_dir/appcast.xml for Inlet $version (build $build)"
