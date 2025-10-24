#!/bin/bash

set -e
DATE_SUFFIX=$(date +%F)


IDENTITY="My Name <me@example.org>"
KEY_TYPE_SIGN="ed25519"
KEY_TYPE_ENC="cv25519"
KEY_TYPE_AUTH="ed25519"
SUBKEY_EXPIRATION="2y"
CERTIFY_PASS="MySecretPassphrase"

KEY_BACKUP_FOLDER="$PWD/backup"
export GNUPGHOME="$PWD/gnupg-create"


log() {
    printf "\033[0;32m%s\033[0m\n" "$@"
}

# Create folders if doesn't exist
if [ ! -d "$KEY_BACKUP_FOLDER" ]; then
    mkdir -p "$KEY_BACKUP_FOLDER"
fi
if [ ! -d "$GNUPGHOME" ]; then
    mkdir -p "$GNUPGHOME"
fi

chmod 700 "$GNUPGHOME"

cp -pf $PWD/hardened-gpg.conf "$GNUPGHOME/gpg.conf"

# Create gpg-agent.conf for batch operations and sandboxing
cat > "$GNUPGHOME/gpg-agent.conf" << EOF
allow-loopback-pinentry
pinentry-program /usr/bin/pinentry-curses
default-cache-ttl 0
max-cache-ttl 0
no-grab
EOF

# Create dirmngr.conf for network isolation
cat > "$GNUPGHOME/dirmngr.conf" << EOF
disable-http
disable-ldap
EOF

# Kill any existing gpg-agent and dirmngr, start fresh
gpgconf --kill gpg-agent
gpgconf --kill dirmngr

log "Starting sandboxed GPG environment in: $GNUPGHOME"

# Generate Master&sign key
log "Generating master key for identity: $IDENTITY"

echo "$CERTIFY_PASS" | \
  gpg --batch --passphrase-fd 0 \
      --quick-generate-key "$IDENTITY" "$KEY_TYPE_SIGN" "cert,sign" never
      
# GET KeyId and KeyFingerprint
KEY_ID=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^pub:/ { print $5; exit }')

KEY_FP=$(gpg -k --with-colons "$IDENTITY" | awk -F: '/^fpr:/ { print $10; exit }')

log "Key ID: $KEY_ID, Key Fingerprint: $KEY_FP"

# Create enc subkey
log "Creating encryption subkey"
echo "$CERTIFY_PASS" | \
    gpg --batch --pinentry-mode=loopback --passphrase-fd 0 \
        --quick-add-key "$KEY_FP" "$KEY_TYPE_ENC" encrypt "$SUBKEY_EXPIRATION"

# Create auth subkey
log "Creating authentication subkey"
echo "$CERTIFY_PASS" | \
    gpg --batch --pinentry-mode=loopback --passphrase-fd 0 \
        --quick-add-key "$KEY_FP" "$KEY_TYPE_AUTH" auth "$SUBKEY_EXPIRATION"
        
# Create revoke certs for all reasons
log "Generating revocation certificates for key ID: $KEY_ID"

# Array of reasons and their names
declare -a reasons=("0:no-reason" "1:compromised" "2:superseded" "3:no-longer-used")

for reason_pair in "${reasons[@]}"; do
    reason_code="${reason_pair%%:*}"
    reason_name="${reason_pair#*:}"
    
    log "Creating revocation certificate for reason: $reason_name ($reason_code)"
    printf '%s\n' "y" "$reason_code" "" "y" "$CERTIFY_PASS" | \
        gpg --command-fd 0 --pinentry-mode=loopback \
            --output "$KEY_BACKUP_FOLDER/$KEY_ID-revoke-$reason_name.asc" --gen-revoke "$KEY_ID"
done

# Export to file
log "Exporting keys to backup folder: $KEY_BACKUP_FOLDER"

echo "$CERTIFY_PASS" | \
    gpg --batch --output "$KEY_BACKUP_FOLDER/$KEY_ID-Certify-Sign.key" \
        --pinentry-mode=loopback --passphrase-fd 0 \
        --armor --export-secret-keys "$KEY_ID"

echo "$CERTIFY_PASS" | \
    gpg --batch --output "$KEY_BACKUP_FOLDER/$KEY_ID-Subkeys.key" \
        --pinentry-mode=loopback --passphrase-fd 0 \
        --armor --export-secret-subkeys "$KEY_ID"

gpg --batch --output "$KEY_BACKUP_FOLDER/$KEY_ID-$DATE_SUFFIX.asc" \
    --armor --export "$KEY_ID"
    
gpg --batch --output "$KEY_BACKUP_FOLDER/$KEY_ID-$DATE_SUFFIX.id.pub" \
    --export-ssh-key "$KEY_ID"

log "Keys and backup files have been generated and stored in $KEY_BACKUP_FOLDER"