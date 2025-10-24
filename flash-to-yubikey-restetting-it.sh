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
gpg --command-fd=0 --pinentry-mode=loopback --edit-key $KEYID <<EOF
key 0
keytocard
y
1
$CERTIFY_PASS
$YUBIKEY_ADMIN_PIN
save
EOF

log "Move the Encryption subkey to YubiKey slot 2"
gpg --command-fd=0 --pinentry-mode=loopback --edit-key $KEYID <<EOF
key 1
keytocard
2
$CERTIFY_PASS
$YUBIKEY_ADMIN_PIN
save
EOF

log "Move the Authentication subkey to YubiKey slot 3"
gpg --command-fd=0 --pinentry-mode=loopback --edit-key $KEYID <<EOF
key 2
keytocard
3
$CERTIFY_PASS
$YUBIKEY_ADMIN_PIN
save
EOF




