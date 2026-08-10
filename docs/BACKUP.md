# Backup and recovery

## Overview

The HP server is the recovery hub. It collects OpenCloud data, Syncthing's
`Vault` and `Shared` folders, selected HP-local files, Keycloak/OpenLDAP
identity data, and GitHub mirrors. A nightly Restic job encrypts and stores
deduplicated snapshots in the private Cloudflare R2 repository. Radicale
calendar and contact data is a separate required staged source.

Synchronization is useful availability, but is not a backup: a deletion or
bad change can synchronize to every peer. Restic snapshots are the off-site,
point-in-time recovery layer.

No credentials, Restic repository contents, or OpenCloud state are stored in
the Git repository. Keep the personal SOPS age identity and the Restic
repository password recoverable independently of HP and R2.

## Backup architecture

### Built-in sources

`my.hpBackup` always backs up these prepared sources. Do not add them again to
`my.hpBackup.extraPaths`.

| Source in a Restic snapshot | What it contains | Consistency method |
| --- | --- | --- |
| `/run/opencloud-backup/current` | Complete OpenCloud state plus captured `/etc/opencloud` configuration | OpenCloud stops for the complete Restic read; xattrs are verified first. |
| `/var/lib/opencloud-identity-backup/latest` | Keycloak PostgreSQL custom dump and OpenLDAP LDIF export | Logical exports while the relevant writers are stopped. |
| `/var/lib/vault-backup/latest` | Syncthing `~/Vault` | Syncthing must be idle, then stops while `rsync -aHAX` stages the data. |
| `/var/lib/shared-backup/latest` | Syncthing `~/Shared` | Same staged boundary as Vault. |
| `/var/lib/radicale-backup/latest` | Radicale calendars, tasks, and contacts | Radicale stops; live and staged storage are verified around an `rsync -aHAX` copy. |
| `/var/lib/github-mirrors/current` | Validated bare Git mirrors | Published only after mirror validation. |
| `/var/lib/hermes-backup/latest` | Hermes export, if a reviewed exporter is configured | Exporter-specific; degraded while no reviewed export exists. |

The sources are defined in `modules/features/backup/restic-s3.nix`.

### HP-local opt-in sources

`hosts/hp-server/configuration.nix` contains `my.hpBackup.extraPaths`. Those
are ordinary files held only on HP, currently including its `Documents`,
`Pictures`, `Music`, `Downloads`, `Video`, and `Desktop` directories.

Add a path there only when all of the following are true:

1. It is an HP-local path, not a laptop path.
2. It is not already one of the built-in sources above.
3. It can safely be read live as ordinary files.

Do not add `/home/henhal/Vault` or `/home/henhal/Shared`: their staged copies
are already included. Do not add `/srv/opencloud/state`; it must only be read
through the stopped-service OpenCloud source. Do not add
`/srv/opencloud/radicale/collections`; use only its validated stage.

### How client files reach backup

| Data owner | Client location | Route to R2 |
| --- | --- | --- |
| OpenCloud personal files | `~/Cloud/Personal/{Documents,Pictures,Music,Shared}` | Desktop/mobile client -> OpenCloud on HP/T7 -> nightly Restic snapshot -> R2 |
| Phone camera roll | OpenCloud Android automatic upload destination, normally `Personal/Pictures/Camera` | Phone -> OpenCloud -> nightly Restic -> R2 |
| Obsidian vault | `~/Vault` | Syncthing -> HP -> staged Vault source -> Restic -> R2 |
| Local shared files | `~/Shared` | Syncthing -> HP -> staged Shared source -> Restic -> R2 |
| Active code | Git/GitHub, not a sync root | GitHub -> HP mirror -> Restic -> R2 |
| Calendars, tasks, and contacts | CalDAV/CardDAV clients using `cloud.henhal.net` | Client -> authenticated OpenCloud proxy -> Radicale on HP/T7 -> validated stage -> Restic -> R2 |

Never place a Syncthing folder inside `~/Cloud`, or make both systems own the
same directory.

## Schedule and expected service interruptions

The `restic-backups-hp-offsite.timer` runs daily at **03:00** in HP's local
time. `Persistent=true` means a run missed while HP was powered off is started
when it next becomes available.

During a run:

1. Keycloak/OpenLDAP, Vault, Shared, Radicale, GitHub, and Hermes sources are prepared.
2. OpenCloud stops while its state is read by Restic, then restarts in cleanup.
3. Syncthing stops briefly once for Vault staging and once for Shared staging.
4. Restic uploads only new encrypted chunks and snapshot metadata to R2.

Radicale stops only while its storage is verified and copied into the private
staging directory. It restarts before Restic reads that immutable stage.

The expected recovery-point objective is about 24 hours. A file is not
off-site protected until it has reached HP and a successful Restic snapshot has
finished.

Useful timer and status checks:

```bash
systemctl list-timers --all restic-backups-hp-offsite.timer
sudo cat /var/lib/restic-status/last-success
sudo jq . /var/lib/restic-status/last-source-status
sudo jq -s . \
  /var/lib/restic-status/opencloud-source.json \
  /var/lib/restic-status/opencloud-identity.json \
  /var/lib/restic-status/vault.json \
  /var/lib/restic-status/shared.json \
  /var/lib/restic-status/radicale.json \
  /var/lib/restic-status/hermes.json \
  /var/lib/github-mirrors/status.json
```

A Restic run can succeed while an auxiliary source is `degraded`; that is not a
fully healthy recovery set. In particular, Hermes remains degraded until a
reviewed native exporter is configured. Radicale is required, so a degraded or
stale Radicale stage suppresses the external success heartbeat until repaired.

## Routine verification

### Run a backup now

This causes the normal short OpenCloud maintenance window.

```bash
sudo systemctl start restic-backups-hp-offsite.service
sudo systemctl --no-pager --full status restic-backups-hp-offsite.service
sudo restic-hp-offsite snapshots
```

Check the deduplicated repository footprint, rather than adding the logical
sizes of every snapshot:

```bash
sudo restic-hp-offsite stats --mode raw-data
```

Run a periodic repository integrity check. `--read-data-subset=5%` reads a
sample of encrypted data; use `--read-data` for a slower complete check.

```bash
sudo restic-hp-offsite check --read-data-subset=5%
```

### Restore and compare one file

Use a temporary target. Never restore over live data merely to test recovery.
For example, this verifies the Shared file staged by Syncthing:

```bash
source_path="/var/lib/shared-backup/latest/contents/Prisfil_neumann.csv"
restore_dir="$(mktemp -d)"

sudo restic-hp-offsite restore latest \
  --target "$restore_dir" \
  --include "$source_path"

sudo cmp "$source_path" "$restore_dir$source_path"
sudo sha256sum "$source_path" "$restore_dir$source_path"
```

`cmp` produces no output on success, and the two SHA-256 values must match.
The restored path contains the staging layout; the original live file is
`/home/henhal/Shared/Prisfil_neumann.csv`.

Clean up only after checking the result:

```bash
sudo rm -rf -- "$restore_dir"
```

## Recovering ordinary files

1. List snapshots and select the desired ID or time:

   ```bash
   sudo restic-hp-offsite snapshots
   sudo restic-hp-offsite ls <snapshot-id>
   ```

2. Restore into a new empty directory, then inspect and copy the needed file
   back manually:

   ```bash
   restore_dir="$(mktemp -d)"
   sudo restic-hp-offsite restore <snapshot-id> \
     --target "$restore_dir" \
     --include /var/lib/shared-backup/latest/contents/<file>
   ```

For an HP-local extra path such as `Documents`, use its direct snapshot path:
`/home/henhal/Documents/<file>`. For Vault, use
`/var/lib/vault-backup/latest/contents/<file>`.

### Restore calendars and contacts into isolation

Never test by restoring over the live Radicale tree. Restore the staged source
to a temporary directory and validate it first:

```bash
restore_dir="$(mktemp -d)"
sudo restic-hp-offsite restore <snapshot-id> \
  --target "$restore_dir" \
  --include /var/lib/radicale-backup/latest

sudo radicale --verify-storage -C /dev/null \
  --auth-type denyall \
  --rights-type owner_only \
  --storage-type multifilesystem \
  --storage-filesystem-folder \
    "$restore_dir/var/lib/radicale-backup/latest/collections" \
  --no-storage-skip-broken-item
```

For a full rehearsal, start a separate Radicale instance on another loopback
port against the restored tree with no Cloudflare exposure. Verify a restored
event, task, recurring event, contact, and contact photo with disposable
credentials before removing the temporary restore.

OpenCloud data is application state, not a normal folder tree. Do not restore
individual files by copying bytes from `/run/opencloud-backup/current/state`.
Recover it through the full OpenCloud procedure below.

## Full HP or T7 recovery

This procedure is intentionally destructive. Perform it only on a replacement
HP/T7 or an isolated recovery environment, never over a working service. The
single-file Restic restore procedure above is tested; the complete isolated
OpenCloud/Keycloak rehearsal remains a required final acceptance test before
depending on the system for irreplaceable data.

### Prerequisites

- A replacement NixOS HP system and the matching dotfiles revision.
- The personal SOPS age identity, available on another trusted machine.
- `secrets/hp-backup.yaml`, including the R2 credentials, repository URL, and
  Restic repository password. These are not recoverable from R2 alone.
- `secrets/opencloud.yaml`, including Keycloak and tunnel credentials. A new
  HP host key must be added as a SOPS recipient and the files rewrapped before
  the replacement can decrypt them at activation.
- A replacement T7 formatted as ext4 with xattrs. The current configuration
  expects UUID `e4577487-f1c0-4aee-bea3-daac8df1633d`; either preserve that UUID
  deliberately or update and review the declarative storage configuration.

### Recovery outline

1. Boot the replacement with networking, but do not expose an empty OpenCloud
   instance publicly. Build/switch the matching configuration only after its
   secrets and T7 mount are ready.
2. Mount a separate, xattr-capable recovery filesystem and restore the chosen
   snapshot into it:

   ```bash
   restore_root=/srv/recovery/restic-restore
   sudo install -d -m 0700 "$restore_root"
   sudo restic-hp-offsite restore <snapshot-id> --target "$restore_root"
   ```

3. Stop the public-facing and stateful services before replacing data:

   ```bash
   sudo systemctl stop cloudflared-tunnel-*.service opencloud.service radicale.service keycloak.service openldap.service
   ```

4. Restore OpenCloud's state to the mounted T7 with metadata preserved. First
   use `--dry-run`; then remove it only after confirming both paths:

   ```bash
   sudo rsync -aHAXn --numeric-ids \
     "$restore_root/run/opencloud-backup/current/state/" \
     /srv/opencloud/state/

   sudo rsync -aHAX --numeric-ids \
     "$restore_root/run/opencloud-backup/current/state/" \
     /srv/opencloud/state/
   ```

5. Restore Keycloak and OpenLDAP from the logical exports in
   `$restore_root/var/lib/opencloud-identity-backup/latest/`. This replaces the
   identity database and directory; first verify the database name, ownership,
   and backup paths on the replacement. Use `pg_restore` for
   `keycloak.pg.dump` and `slapadd` for `opencloud-ldap.ldif` only while their
   respective services are stopped. Preserve the old, failed directories until
   the recovered service has been verified.
6. Restore HP-local paths and Syncthing data as needed using `rsync -aHAX` from
   the restored snapshot. For example, Shared comes from
   `$restore_root/var/lib/shared-backup/latest/contents/` and Vault from
   `$restore_root/var/lib/vault-backup/latest/contents/`.
7. With Radicale stopped, restore its selected validated collection tree from
   `$restore_root/var/lib/radicale-backup/latest/collections/` to
   `/srv/opencloud/radicale/collections/` using `rsync -aHAX --numeric-ids`.
   Verify storage, ownership `radicale:radicale`, and restrictive modes before
   starting the service.
8. Start OpenLDAP, PostgreSQL/Keycloak, Radicale, OpenCloud, and finally the tunnel.
   Verify local loopback listeners, Keycloak login and MFA, browser/desktop/
   Android access, DAV discovery and read/write using a disposable app token,
   and a disposable upload before re-enabling normal use.
9. Run a new successful Restic backup and keep the pre-recovery snapshot until
   the replacement has been stable for a reviewed period.

The exact Keycloak/OpenLDAP replacement commands are deliberately not a
one-line copy/paste operation: they overwrite authentication state. Perform
them first in an isolated recovery rehearsal, record the verified commands for
the installed NixOS versions, then add them to this runbook.

## What not to do

- Do not expose the R2 repository as a mount, file browser, WebDAV share, or
  OpenCloud Space.
- Do not copy live `/srv/opencloud/state` while OpenCloud is running.
- Do not copy live `/srv/opencloud/radicale/collections` while Radicale is
  running or add it to `my.hpBackup.extraPaths`.
- Do not restore over a live OpenCloud state tree without stopping its service.
- Do not use Syncthing replicas as proof of backup.
- Do not add automatic `forget`/`prune` or R2 lifecycle deletion without a
  reviewed retention policy and a tested recovery window.
