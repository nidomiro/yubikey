#!/bin/bash

set -e

. ${PWD}/config.sh
. ${PWD}/common.sh

init_gnupg_home

# Global array to store available key IDs
declare -a AVAILABLE_KEYS

# Function to list available key IDs from backup folder
list_available_keys() {
    AVAILABLE_KEYS=()
    
    log "Scanning backup folder for available keys..."
    log "Looking in: $KEY_BACKUP_FOLDER"
    
    # Check if backup folder exists
    if [ ! -d "$KEY_BACKUP_FOLDER" ]; then
        log "Error: Backup folder does not exist: $KEY_BACKUP_FOLDER"
        exit 1
    fi
    
    # Look for Certify-Sign key files to determine available keys
    for file in "$KEY_BACKUP_FOLDER"/*-Certify-Sign.key; do
        log "Checking file: $file"
        [ -f "$file" ] || continue
        filename=$(basename "$file")
        # Extract key ID from filename (everything before -Certify-Sign.key)
        key_id="${filename%-Certify-Sign.key}"
        log "Found key ID: $key_id"
        AVAILABLE_KEYS+=("$key_id")
    done
    
    log "Total keys found: ${#AVAILABLE_KEYS[@]}"
    
    if [ ${#AVAILABLE_KEYS[@]} -eq 0 ]; then
        log "No backup keys found in $KEY_BACKUP_FOLDER"
        log "Looking for files matching pattern: *-Certify-Sign.key"
        log "Files in backup folder:"
        ls -la "$KEY_BACKUP_FOLDER" || log "Cannot list backup folder"
        exit 1
    fi
}

# Function to show selection menu
select_key_id() {
    log "Available key IDs in backup folder:"
    for i in "${!AVAILABLE_KEYS[@]}"; do
        printf "\033[0;33m%d)\033[0m %s\n" "$((i+1))" "${AVAILABLE_KEYS[i]}"
    done
    echo
    
    while true; do
        printf "\033[0;36mSelect key ID to import (1-${#AVAILABLE_KEYS[@]}):\033[0m "
        read choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#AVAILABLE_KEYS[@]} ]; then
            SELECTED_KEY_ID="${AVAILABLE_KEYS[$((choice-1))]}"
            return
        else
            printf "\033[0;31mInvalid choice. Please select a number between 1 and ${#AVAILABLE_KEYS[@]}.\033[0m\n"
        fi
    done
}

# Get available keys and let user select
list_available_keys
select_key_id

log "Selected key ID: $SELECTED_KEY_ID"

# Import all key files for the selected key ID (except revocation certificates)
log "Importing keys for key ID: $SELECTED_KEY_ID"

# Import public key
public_key_file="$KEY_BACKUP_FOLDER/$SELECTED_KEY_ID-"*".asc"
if ls $public_key_file 1> /dev/null 2>&1; then
    for file in $public_key_file; do
        log "Importing public key: $(basename "$file")"
        gpg --batch --import "$file"
    done
else
    log "Warning: No public key file found for $SELECTED_KEY_ID"
fi

# Import master key (Certify-Sign)
certify_sign_file="$KEY_BACKUP_FOLDER/$SELECTED_KEY_ID-Certify-Sign.key"
if [ -f "$certify_sign_file" ]; then
    log "Importing master key (Certify-Sign): $(basename "$certify_sign_file")"
    gpg --batch --import "$certify_sign_file"
else
    log "Warning: No Certify-Sign key file found for $SELECTED_KEY_ID"
fi

# Import subkeys
subkeys_file="$KEY_BACKUP_FOLDER/$SELECTED_KEY_ID-Subkeys.key"
if [ -f "$subkeys_file" ]; then
    log "Importing subkeys: $(basename "$subkeys_file")"
    gpg --batch --import "$subkeys_file"
else
    log "Warning: No Subkeys file found for $SELECTED_KEY_ID"
fi


log "Key import completed for key ID: $SELECTED_KEY_ID"
log "Revocation certificates were NOT imported (they remain in backup for emergency use)"

# Show imported keys
log "Imported keys:"
gpg --list-keys "$SELECTED_KEY_ID"


