#!/usr/bin/env bash
# Makes the free, self-signed code-signing certificate that signs every Inlet release.
#
# Run this once, on your Mac or any machine with openssl. It writes three files into
# ~/inlet-signing (folder mode 700). Nothing is committed to the repo.
#
#   inlet-code-signing.p12     the certificate and its private key. Back this up.
#   CODE_SIGN_P12.txt          the same file, base64 encoded, for the CODE_SIGN_P12 secret.
#   CODE_SIGN_P12_PASSWORD.txt the password, for the CODE_SIGN_P12_PASSWORD secret.
#
# Why bother: macOS ties privacy grants to the app's code signing identity. This
# certificate is the same on every build and release, so the grants survive updates.
# Ad-hoc signing changes the identity on every build, which makes macOS ask again.
#
# It is not trusted by Apple, so Gatekeeper still blocks the first download. See
# RELEASING.md, "Installing an unsigned build".
#
# Usage: scripts/release/make-signing-certificate.sh [output-folder]

set -euo pipefail

NAME="Inlet Release Signing"
OUT="${1:-$HOME/inlet-signing}"

if [ -e "$OUT/inlet-code-signing.p12" ]; then
  echo "error: $OUT/inlet-code-signing.p12 already exists. Remove it first if you really want a new identity." >&2
  echo "       A new identity is a new app to macOS: privacy grants reset and existing installs can't update." >&2
  exit 1
fi

mkdir -p "$OUT"
chmod 700 "$OUT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSWORD="$(openssl rand -hex 24)"

cat > "$WORK/openssl.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no

[dn]
CN = $NAME

[v3]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
CONF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -config "$WORK/openssl.cnf" \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem"

# The 3DES/SHA-1 options matter: macOS's `security import` can't read the newer
# OpenSSL 3 PKCS#12 defaults.
openssl pkcs12 -export \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$NAME" \
  -out "$OUT/inlet-code-signing.p12" \
  -passout "pass:$PASSWORD" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

openssl base64 -A -in "$OUT/inlet-code-signing.p12" > "$OUT/CODE_SIGN_P12.txt"
printf '%s' "$PASSWORD" > "$OUT/CODE_SIGN_P12_PASSWORD.txt"
chmod 600 "$OUT"/*

cat <<DONE

Created the certificate "$NAME" in $OUT

Next, add the two secrets to the repo (run on the machine that has the gh CLI):

  gh secret set CODE_SIGN_P12 --repo FreezingShock/Inlet < "$OUT/CODE_SIGN_P12.txt"
  gh secret set CODE_SIGN_P12_PASSWORD --repo FreezingShock/Inlet < "$OUT/CODE_SIGN_P12_PASSWORD.txt"

Then delete the plain copies. Keep inlet-code-signing.p12 in a password manager.
Losing it means a new identity, which breaks updates for existing installs.

  rm "$OUT/CODE_SIGN_P12.txt" "$OUT/CODE_SIGN_P12_PASSWORD.txt"

To sign local Xcode builds with the same identity (so they keep the same grants), import it:

  security import "$OUT/inlet-code-signing.p12" -k ~/Library/Keychains/login.keychain-db \\
    -P "<password from your password manager>" -T /usr/bin/codesign

and build with: CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$NAME"
DONE
