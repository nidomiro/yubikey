
DATE_SUFFIX=$(date +%F)

IDENTITY="My Name <me@example.org>"
KEY_TYPE_SIGN="ed25519"
KEY_TYPE_ENC="cv25519"
KEY_TYPE_AUTH="ed25519"
SUBKEY_EXPIRATION="2y"
CERTIFY_PASS="MySecretPassphrase"

KEY_BACKUP_FOLDER="$PWD/backup"
export GNUPGHOME="$PWD/gnupg-create"