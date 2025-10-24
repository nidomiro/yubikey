#!/bin/bash

set -e

. ${PWD}/config.sh
. ${PWD}/common.sh

DEFAULT_USER_PIN="123456"
DEFAULT_ADMIN_PIN="12345678"

# Ensure required variables are set and non-empty
: "${YUBIKEY_USER_PIN:?YUBIKEY_USER_PIN is not set or empty}"
: "${YUBIKEY_ADMIN_PIN:?YUBIKEY_ADMIN_PIN is not set or empty}"
: "${YUBIKEY_PGP_RETRIES:?YUBIKEY_PGP_RETRIES is not set or empty}"


echo -e "\e[31mcontinuing this script will reset the openpgp functionality of your yubikey, do you really want to continue? (y|N)\e[0m"
read -r answer
if [[ ! "$answer" =~ ^[yY]$ ]]; then
    echo "Aborted."
    exit 1
fi

command -v ykman >/dev/null 2>&1 || { echo "ykman is not installed or not in PATH."; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo "gpg is not installed or not in PATH."; exit 1; }

# Function to list available secret keys
list_available_secret_keys() {
    AVAILABLE_SECRET_KEYS=()
    
    log "Scanning for available secret keys..."
    
    # Get secret keys with key IDs
    local secret_keys=$(gpg --list-secret-keys --with-colons | grep '^sec:' | cut -d: -f5)
    
    for key_id in $secret_keys; do
        # Get the identity (name and email) for this key
        local identity=$(gpg --list-keys --with-colons "$key_id" | grep '^uid:' | head -1 | cut -d: -f10)
        AVAILABLE_SECRET_KEYS+=("$key_id:$identity")
    done
    
    if [ ${#AVAILABLE_SECRET_KEYS[@]} -eq 0 ]; then
        log "No secret keys found in GPG keyring"
        log "Please import keys first using ./import-key-backup.sh"
        exit 1
    fi
}

# Function to show key selection menu
select_secret_key() {
    log "Available secret keys:"
    for i in "${!AVAILABLE_SECRET_KEYS[@]}"; do
        local key_pair="${AVAILABLE_SECRET_KEYS[i]}"
        local key_id="${key_pair%%:*}"
        local identity="${key_pair#*:}"
        printf "\033[0;33m%d)\033[0m %s - %s\n" "$((i+1))" "$key_id" "$identity"
    done
    echo
    
    while true; do
        printf "\033[0;36mSelect key to transfer to YubiKey (1-${#AVAILABLE_SECRET_KEYS[@]}):\033[0m "
        read choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#AVAILABLE_SECRET_KEYS[@]} ]; then
            local selected_pair="${AVAILABLE_SECRET_KEYS[$((choice-1))]}"
            SELECTED_KEY_ID="${selected_pair%%:*}"
            return
        else
            printf "\033[0;31mInvalid choice. Please select a number between 1 and ${#AVAILABLE_SECRET_KEYS[@]}.\033[0m\n"
        fi
    done
}

# Global arrays for key selection
declare -a AVAILABLE_SECRET_KEYS
SELECTED_KEY_ID=""

# Get available secret keys and let user select
list_available_secret_keys
select_secret_key

log "Selected key ID: $SELECTED_KEY_ID"
KEY_ID="$SELECTED_KEY_ID"


log "Resetting YubiKey OpenPGP applet..."
ykman openpgp reset


log "Enabling KDF on YubiKey..."
echo "admin
kdf-setup
${DEFAULT_ADMIN_PIN}
" | gpg --command-fd=0 --pinentry-mode=loopback --card-edit


log "Setting User PIN"
echo "1
$DEFAULT_USER_PIN
$YUBIKEY_USER_PIN
$YUBIKEY_USER_PIN
q" | gpg --command-fd=0 --pinentry-mode=loopback --change-pin


log "Setting Admin PIN"
echo "3
$DEFAULT_ADMIN_PIN
$YUBIKEY_ADMIN_PIN
$YUBIKEY_ADMIN_PIN
q" | gpg --command-fd=0 --pinentry-mode=loopback --change-pin


log "Setting PIN retry counters"
ykman openpgp access set-retries $YUBIKEY_PGP_RETRIES -f -a $YUBIKEY_ADMIN_PIN


log "Set Info on YubiKey OpenPGP applet"
gpg --command-fd=0 --pinentry-mode=loopback --edit-card <<EOF
admin
login
$IDENTITY
$YUBIKEY_ADMIN_PIN
quit
EOF

log "Move the Certify&Sign key to YubiKey slot 1"
gpg --command-fd=0 --pinentry-mode=loopback --edit-key $KEY_ID <<EOF
key 0
keytocard
y
1
$CERTIFY_PASS
$YUBIKEY_ADMIN_PIN
save
EOF

log "Move the Encryption subkey to YubiKey slot 2"
gpg --command-fd=0 --pinentry-mode=loopback --edit-key $KEY_ID <<EOF
key 1
keytocard
2
$CERTIFY_PASS
$YUBIKEY_ADMIN_PIN
save
EOF

log "Move the Authentication subkey to YubiKey slot 3"
gpg --command-fd=0 --pinentry-mode=loopback --edit-key $KEY_ID <<EOF
key 2
keytocard
3
$CERTIFY_PASS
$YUBIKEY_ADMIN_PIN
save
EOF




