# Obsidian Self-hosted LiveSync

## Overview

The Obsidian vault (`~/Vault` on every device) is synchronized in real time by
the [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync)
plug-in. Each device replicates with one CouchDB database on HP. HP has no
Obsidian installation; it runs the official headless LiveSync CLI, which keeps
a plain-file copy of the vault in `/home/henhal/Vault`. That copy is what the
nightly Restic backup stages.

LiveSync must be the only sync system for the vault. Do not add `Vault` back
to Syncthing, use Remotely Save, or place the vault inside `~/Cloud`.

Only notes and attachments synchronize. Hidden-file sync and customization
(plug-in/settings) sync stay off, so `.obsidian/` is configured per device.

## Service layout

| Component | Address and role |
| --- | --- |
| Public endpoint | `https://obsidian-livesync.henhal.net`, through the existing Cloudflare tunnel and Cloudflare Access |
| CouchDB | `127.0.0.1:5984` on HP, `couchdb.service` |
| CouchDB data | `/srv/opencloud/couchdb/data` on the T7 |
| Provisioning | `couchdb-livesync-provision.service`: creates the `obsidian` database and its permissions, then verifies that anonymous access is refused |
| HP Vault mirror | `docker-obsidian-livesync-cli.service`: the official `ghcr.io/vrtmrz/livesync-cli` image in `daemon` mode |
| CLI state | `/var/lib/obsidian-livesync-cli` (local PouchDB and `settings.json`) |
| Module | `modules/features/cloud/obsidian-livesync.nix` (`my.obsidianLivesync`) |
| Secrets | `secrets/obsidian-livesync.yaml` |

The CLI reaches CouchDB on loopback (`--network=host`) and never uses the
tunnel. CouchDB rejects every connection that does not come from loopback.

## Security model

- **Cloudflare Access service token.** Requests without the
  `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers stop at
  Cloudflare. Each device sends them as LiveSync custom headers. No browser
  login is involved, so this does not hit the OIDC problems that rule Access
  out for `cloud.henhal.net`.
- **CouchDB login.** `require_valid_user_except_for_up` refuses every
  anonymous request except the health endpoint `/_up`.
- **End-to-end encryption and path obfuscation.** CouchDB, the T7 and Restic
  only hold encrypted chunks and hashed paths. HP's CLI holds the passphrase
  so it can write plain files.
- The LiveSync account `obsidian` is a **CouchDB server admin**. The plug-in's
  "Overwrite server data" and the CLI's `rebuild` delete and recreate the
  database, and CouchDB allows only server admins to do that. This instance
  hosts nothing else. A separate `admin` account is used only by HP's
  provisioning service.
- Every runtime CouchDB configuration change is discarded at restart. The
  writable `local.ini` lives in `/run/couchdb`, and the declarative settings
  come from Nix plus the SOPS-rendered `couchdb-secrets.ini`.

## Secrets

`secrets/obsidian-livesync.yaml` is decrypted only on HP and by the personal
age keys:

| Key | Use |
| --- | --- |
| `COUCHDB_ADMIN_PASSWORD` | Maintenance `admin` account (provisioning only) |
| `COUCHDB_AUTH_SECRET` | CouchDB cookie-signing secret |
| `LIVESYNC_COUCHDB_PASSWORD` | Password of the `obsidian` account used by every device and the CLI |
| `LIVESYNC_E2EE_PASSPHRASE` | End-to-end encryption and path-obfuscation passphrase |

Read a value on the workstation or Lenovo:

```bash
nix shell nixpkgs#sops -c sops -d --extract '["LIVESYNC_E2EE_PASSPHRASE"]' secrets/obsidian-livesync.yaml
```

**Store `LIVESYNC_E2EE_PASSPHRASE` in the password manager and with the offline
recovery material.** Without it, neither CouchDB nor its Restic copy can be
decrypted. The plain-file Vault copy in Restic remains readable.

Do not change the passphrase after the initial upload. A new passphrase
requires rebuilding the remote database and fetching it again on every device.
The `obsidian` password can be rotated: edit the secret, rebuild HP, then
update the password in each device's LiveSync settings.

The Cloudflare Access service token is not stored in this repository. It
lives in Cloudflare and in each device's LiveSync settings and Setup URI.

## Cloudflare configuration (manual)

1. **DNS route:** route `obsidian-livesync.henhal.net` to tunnel
   `d5383138-72c4-4879-924a-319edc4c20c6`, the same way as the other
   hostnames. The ingress rule itself comes from Nix.
2. **Service token:** in Zero Trust, open **Access -> Service credentials ->
   Service Tokens** and create `obsidian-livesync`. Copy the Client ID and
   Client Secret immediately.
3. **Access application:** create a self-hosted application for
   `obsidian-livesync.henhal.net` with one policy, action **Service Auth**,
   that includes that service token. In the application's **CORS settings**,
   enable **Bypass OPTIONS requests to origin**. Browser pre-flight requests
   carry no custom headers; CouchDB answers them.
4. **Cache:** add a cache-bypass rule for the hostname, like the existing ones.
5. **Rate limiting (recommended):** limit request rate per IP on the hostname.
6. If Bot Fight Mode or Browser Integrity Check is enabled for the zone, make
   sure it does not challenge this hostname. Clients are not browsers.

Check from outside HP. The first request must stop at Access (`403`). The
second reaches CouchDB, which demands a login (`401`):

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://obsidian-livesync.henhal.net/
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "CF-Access-Client-Id: <id>" -H "CF-Access-Client-Secret: <secret>" \
  https://obsidian-livesync.henhal.net/
```

## Migration from Remotely Save and Syncthing

The workstation's `~/Vault` is the authoritative copy.

1. **Stop the old sync systems.** Disable the Remotely Save plug-in on every
   device (workstation, Lenovo, phone, tablet). Run a fresh backup on HP so
   the current Syncthing copy is in a snapshot:

   ```bash
   sudo systemctl start restic-backups-hp-offsite.service
   ```

2. **Deploy.** Rebuild HP and the workstation; Lenovo can follow later. The
   Syncthing `vault` folder disappears from both hosts' Syncthing
   configuration, but the files stay where they are. Until step 6, the Vault
   backup source reports `degraded`, which is expected.
3. **Verify HP:**

   ```bash
   systemctl is-active couchdb.service couchdb-livesync-provision.service
   curl -s http://127.0.0.1:5984/_up                                    # {"status":"ok",...}
   curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5984/obsidian   # 401
   ```

   `docker-obsidian-livesync-cli.service` is skipped (condition not met) until
   step 6.
4. **Cloudflare:** complete the section above and run both checks.
5. **Workstation: upload the vault.**
   1. Keep a safety copy: `cp -a ~/Vault ~/Vault.pre-livesync-$(date +%F)`.
   2. Delete the old `*.sync-conflict-*` files in `~/Vault` after reviewing
      them, and remove `~/Vault/.obsidian/plugins/remotely-save`.
   3. Install **Self-hosted LiveSync** from the community plug-ins and
      configure it manually:
      - Remote type: CouchDB. URI `https://obsidian-livesync.henhal.net`,
        username `obsidian`, password `LIVESYNC_COUCHDB_PASSWORD`, database
        `obsidian`.
      - Custom headers (one per line):
        `CF-Access-Client-Id: <id>` and `CF-Access-Client-Secret: <secret>`.
      - End-to-end encryption on with `LIVESYNC_E2EE_PASSPHRASE`; path
        obfuscation on.
      - Sync mode LiveSync. Hidden-file sync and customization sync off.
   4. Run **Overwrite Server Data with This Device's Files** (Rebuild).
   5. Run the command **Copy settings as a new Setup URI** and keep the URI and
      its passphrase until every device is set up.
6. **HP: create the plain-file mirror.**

   ```bash
   mv ~/Vault ~/Vault.syncthing-$(date +%F)
   mkdir ~/Vault
   sudo obsidian-livesync-hp-init
   ```

   The helper refuses a non-empty `~/Vault`. It writes the CLI settings,
   fetches the database into `~/Vault`, creates
   `/var/lib/obsidian-livesync-cli/initialised`, and starts the daemon.
   Compare against the workstation, for example by file count:
   `find ~/Vault -type f | wc -l`.
7. **Other devices (Lenovo, phone, tablet).** Start each from an empty vault
   folder; move or delete the old local copy first. Install the plug-in, choose
   **Use a Setup URI**, paste the URI, and accept fetching from the remote
   ("Reset synchronisation on this device"). Never fetch into a vault that
   still contains old files, because those become conflicts.
8. **Check the backup source:**

   ```bash
   sudo systemctl start vault-backup-stage.service
   sudo jq . /var/lib/restic-status/vault.json   # result: healthy
   ```

9. After a few stable weeks, delete OpenCloud's `Personal/Vault`,
   `~/Vault.syncthing-*` on HP, and `~/Vault.pre-livesync-*` on the workstation.

Make one test edit on each device and confirm that it appears everywhere,
including in HP's `~/Vault`.

## Operations

```bash
systemctl status couchdb.service couchdb-livesync-provision.service docker-obsidian-livesync-cli.service
journalctl -u docker-obsidian-livesync-cli.service -f       # CLI daemon log
journalctl -u couchdb.service --since '15 minutes ago'
```

At 03:00 the backup briefly stops the CLI daemon and CouchDB while
`vault-backup-stage.service` copies `~/Vault` and the CouchDB data. Devices
retry and catch up on their own. Changes made on HP while the daemon is
stopped are picked up when it restarts.

### Upgrading

Keep the CLI image and the plug-in on the same release, because they share the
LiveSync core library. To upgrade, update the plug-in on the devices, then
pin the matching `<version>-cli` image in `obsidian-livesync.nix`:

```bash
nix run nixpkgs#nix-prefetch-docker -- --image-name ghcr.io/vrtmrz/livesync-cli \
  --image-tag <version>-cli --arch amd64 --os linux
```

Copy `imageDigest`, `hash`, and `finalImageTag` into `cliImage`, update
`cliImageRef`, and rebuild HP.

## Recovery

- **From the plain files (preferred):** restore
  `/var/lib/vault-backup/latest/contents/` from Restic (see
  [BACKUP.md](BACKUP.md)), place it as the vault on one device, and run
  **Overwrite Server Data with This Device's Files**. Then fetch on every other
  device, and on HP stop the daemon, remove
  `/var/lib/obsidian-livesync-cli/initialised`, empty `~/Vault`, and run
  `sudo obsidian-livesync-hp-init` again.
- **From the CouchDB copy:** with `docker-obsidian-livesync-cli.service` and
  `couchdb.service` stopped, restore
  `/var/lib/vault-backup/latest/couchdb/` to `/srv/opencloud/couchdb/data/`
  with `rsync -aHAX --numeric-ids`, run `chown -R couchdb:couchdb` on it, and
  start CouchDB. Reading it requires the E2EE passphrase.

## Troubleshooting

- **`403` from Cloudflare on a device:** the custom headers are missing or
  wrong, or the service token expired. Cloudflare service tokens have an
  expiry date; renew the token and update every device.
- **CLI daemon not running:** if `systemctl status` shows the condition
  failed, the mirror was never initialised. Check that
  `couchdb-livesync-provision.service` succeeded.
- **Conflicts:** resolve them in Obsidian on a device. The CLI keeps
  conflicting revisions in the database instead of overwriting files.
