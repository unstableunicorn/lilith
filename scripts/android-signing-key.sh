#!/usr/bin/env bash
# Make the Android test signing key once and hand it to GitHub Actions as
# secrets, so every CI build installs over the last. Run it yourself: it
# writes the key and its password only under $XDG_RUNTIME_DIR and into the
# repository's secrets, never into git or the terminal.
#
# Usage: scripts/android-signing-key.sh
# Afterwards copy $XDG_RUNTIME_DIR/lilith-signing/ somewhere safe (it is a
# tmpfs, gone at reboot). Losing the key means every user reinstalls.
set -euo pipefail

cd "$(dirname "$0")/.." || exit 1
dir="${XDG_RUNTIME_DIR:?}/lilith-signing"
mkdir -p "$dir"
chmod 700 "$dir"

if [ ! -f "$dir/store.pass" ]; then
  openssl rand -base64 30 | tr -d '\n' > "$dir/store.pass"
  chmod 600 "$dir/store.pass"
fi
if [ ! -f "$dir/lilith-test.jks" ]; then
  keytool -genkeypair -storetype PKCS12 -keystore "$dir/lilith-test.jks" \
    -alias lilith -keyalg RSA -keysize 4096 -validity 10000 \
    -storepass:file "$dir/store.pass" -keypass:file "$dir/store.pass" \
    -dname "CN=Lilith test signing, O=unstableunicorn" >/dev/null
fi
base64 -w0 "$dir/lilith-test.jks" > "$dir/keystore.b64"

gh secret set ANDROID_KEYSTORE_BASE64 < "$dir/keystore.b64"
gh secret set ANDROID_KEYSTORE_PASSWORD < "$dir/store.pass"
echo "Secrets set. Key and password are in $dir; copy them somewhere safe."
