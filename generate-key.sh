#!/bin/bash

set -e


. ${PWD}/config.sh
. ${PWD}/common.sh

if [ ! -d "$KEY_BACKUP_FOLDER" ]; then
        mkdir -p "$KEY_BACKUP_FOLDER"
    fi



init_gnupg_home

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