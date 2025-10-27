# Yubikey stuff

## Prepare

Checkout this repo un a secure device, eg. in an encrypted container while using a live distro.

```shell
cp config.sh.example config.sh
```

Then edit `config.sh` and set your desired configuration.

### Software

```shell
sudo dnf install yubikey-manager
```

## Usage

First generate the keys:

```shell
./generate-key.sh
```

Dependeing on your system, you can now import the keys to your yubikey via the script.
If you get errors like `gpg: selecting card failed: No such device` you have a conflicting gpg instance, accessing your yubikey. As I'm on a live system, I will change the `GNUPGHOME` to `"$HOME/.gnupg"` and use the general instance. This also has the benefit, that the local gpg instance (the one here in this repo on a encrypted device) still has the keys imported.

Import the backup:

```shell
./import-key-backup.sh
```

Move the keys to the yubikey and configure it:

```shell
./flash-to-yubikey-restetting-it.sh
```

Check your keys actually moved by looking for `sec>` and `ssb>`:

```shell
gpg -K
/home/liveuser/.gnupg/pubring.kbx
---------------------------------
sec>  ed25519/0x0000000000000000 2025-10-25 [SC]
      Key fingerprint = 0000 0000 0000 0000 0000  0000 0000 0000 0000 0000
      Card serial no. = 0000 00000000
uid                   [ unknown] My Name <me@example.org>
ssb>  cv25519/0x0000000000000000 2025-10-25 [E] [expires: 2027-10-25]
ssb>  ed25519/0x0000000000000000 2025-10-25 [A] [expires: 2027-10-25]
```

You can now use your yubikey.
It may be a good Idea to copy of your public keys (`*.pub.asc` and `*.id.pub`) to a non-encrypted place.

## Configure touch and PIN caching

You may want to disable forcesig and enable touch for signing.
In the following setup you will have to enter your PIN once and touch the yubikey for the first time. If a signing request happens within the next 15 seconds, no touch is required. After 15 seconds a touch is required again, but no PIN entry.

```shell
gpg --edit-card
# ...
# Signature PIN ....: forced
# ...
#> admin
#> forcesig
#> quit
```

When executing `gpg --card-status` you should see:

```
Signature PIN ....: not forced
```

Enable (cached) touch for signing:

```shell
ykman openpgp keys set-touch sig cached
```

for other options see:

```shell
ykman openpgp keys set-touch --help
```

## Set URL in opengpg on yubikey

You can set a URL to your public keyserver entry in the yubikey's OpenPGP applet.
With this, you can download the public key directly via:

```shell
gpg --card-edit
#> fetch
```

To set the URL, use:

```shell
gpg --edit-card
#> admin
#> url
#> <enter your URL here>
#> quit
```
