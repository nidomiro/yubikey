log() {
    printf "\033[0;34m%s\033[0m\n" "$@"
}

function init_gnupg_home() {
    # Create folders if doesn't exist
    
    if [ -d "$GNUPGHOME" ]; then
        log "GPG home folder already exists, reusing it: $GNUPGHOME"
        return
    fi
    log "Creating new GPG home folder: $GNUPGHOME"

    mkdir -p "$GNUPGHOME"


    chmod 700 "$GNUPGHOME"

    # Copy hardened GPG configuration files
    cp -pf "$PWD/hardened-gpg/gpg.conf" "$GNUPGHOME/gpg.conf"
    cp -pf "$PWD/hardened-gpg/gpg-agent.conf" "$GNUPGHOME/gpg-agent.conf"
    cp -pf "$PWD/hardened-gpg/dirmngr.conf" "$GNUPGHOME/dirmngr.conf"

    # Kill any existing gpg-agent and dirmngr, start fresh
    gpgconf --kill gpg-agent
    gpgconf --kill dirmngr

    log "Created sandboxed GPG environment in: $GNUPGHOME"
}