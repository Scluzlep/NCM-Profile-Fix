#!/usr/bin/env bash
# Run once on a trusted machine with keytool, openssl, base64 and GitHub CLI.
# The keystore is retained locally; its bytes and passwords are stored as GitHub Actions Secrets.
set -euo pipefail
REPO="Scluzlep/NCM-Profile-Fix"
KEYFILE="${1:-ncm-profile-fix-release.p12}"
if [ -e "$KEYFILE" ]; then
  echo "Refusing to overwrite existing signing key: $KEYFILE" >&2
  exit 1
fi
for cmd in keytool openssl base64 gh; do
  command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }
done
gh auth status >/dev/null
umask 077
PASSWORD="$(openssl rand -hex 28)"
ALIAS="ncm-profile-fix"
keytool -genkeypair -keystore "$KEYFILE" -storetype PKCS12 \
  -alias "$ALIAS" -keyalg RSA -keysize 3072 -validity 36500 \
  -storepass "$PASSWORD" -keypass "$PASSWORD" \
  -dname "CN=NCM Profile Fix, OU=Android, O=Scluzlep, C=US" -noprompt
base64 < "$KEYFILE" | tr -d '\n' | gh secret set KEYSTORE_BASE64 --repo "$REPO"
printf '%s' "$PASSWORD" | gh secret set KEYSTORE_PASSWORD --repo "$REPO"
printf '%s' "$PASSWORD" | gh secret set KEY_PASSWORD --repo "$REPO"
printf '%s' "$ALIAS" | gh secret set KEY_ALIAS --repo "$REPO"
BACKUP="${KEYFILE}.password.txt"
printf 'Signing keystore: %s\nAlias: %s\nPassword: %s\n' "$KEYFILE" "$ALIAS" "$PASSWORD" > "$BACKUP"
chmod 600 "$KEYFILE" "$BACKUP"
printf 'Secrets configured for %s. Back up both files securely:\n  %s\n  %s\n' "$REPO" "$KEYFILE" "$BACKUP"
