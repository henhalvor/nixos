# Security Practices

This document defines the security rules for the NixOS hosts managed by this
repository: `workstation`, `lenovo-yoga-pro-7`, and `hp-server`. It describes
the standard to preserve when adding hosts, services, users, network access,
secrets, synchronization, and backups.

Security-sensitive changes must remain narrow, reviewable, reversible, and
tested on one host at a time. A successful Nix evaluation is necessary but is
not proof that login, recovery, firewall, or restore paths work at runtime.

## Core principles

- Grant access through the feature that requires it, not through global base
  configuration.
- Expose services only to the network and identities that consume them.
- Keep plaintext secrets out of Git, the Nix store, command arguments, logs,
  shell history, and world/group-readable files.
- Treat synchronization, service availability, and backup as different
  concerns.
- Preserve a tested recovery path before narrowing authentication or network
  access.
- Never deploy unrelated security changes together merely because they touch
  the same host.
- Do not automate destructive retention, pruning, storage migration, reboot,
  or credential revocation without a separately reviewed procedure.

## Accounts and local authentication

- Never use `initialPassword`, plaintext passwords, or known default passwords.
- Store only a strong yescrypt password hash in SOPS and consume it through
  `users.users.<name>.hashedPasswordFile`.
- Mark password-hash secrets with `neededForUsers = true`, owner `root`, and
  mode `0400`. They must not belong to the interactive `keys` group.
- Keep `users.mutableUsers` unchanged unless a planned migration explains how
  existing passwords and emergency access will behave.
- Test local login and `sudo` on the physical machine before deploying SSH or
  firewall restrictions to that host.
- Keep at least one local-console or LAN recovery path independent of
  Tailscale.

## Groups and privileged features

User-group membership must follow enabled features:

- `docker` is owned by the Docker feature. Membership is root-equivalent and
  must exist only on hosts that intentionally enable Docker.
- `i2c` is owned by the external-monitor brightness feature.
- `lp` and `scanner` are owned by the printer feature.
- Device-specific udev permissions belong to the corresponding device feature,
  such as Vial.
- General user identity may retain genuinely cross-host groups such as `wheel`
  and `networkmanager`, but host-specific privileges do not belong there.

When adding a privileged feature, document why the host and user need it.
Removing the feature should also remove its group membership and device rules.

## SSH

- Allow public-key authentication only.
- Keep password and keyboard-interactive SSH authentication disabled.
- Keep direct root login disabled.
- Use PAM for account and session handling while retaining key-only SSH.
- Prefer maintained OpenSSH cipher, MAC, and key-exchange defaults. Add a
  compatibility override only for a verified active client, scoped as narrowly
  as possible, and record why it exists.
- Give every retained authorized key a stable device-and-purpose comment.
- Do not revoke an unidentified key until independent administrative access is
  verified. Follow [the deferred key audit](../tasks/ssh-key-audit.md).
- Review successful-login fingerprints and remove obsolete keys deliberately.
- Keep fail2ban limits meaningful on LAN-reachable SSH; it is supplementary and
  does not replace key-only authentication or network policy.

## Tailscale and firewall policy

- Never place `tailscale0` in `networking.firewall.trustedInterfaces`.
- Open only explicit per-interface ports required by SSH, Mosh, Syncthing, or a
  reviewed service.
- Prefer services bound to loopback and exposed through Tailscale Serve over
  services listening directly on every interface.
- Firewall rules and tailnet grants are separate controls. Both must be
  reviewed and tested.
- Separate host administration, HP application access, and ordinary-device
  access in the tailnet policy.
- Do not open monitoring or future-service ports before those services are
  implemented.
- Follow [Tailscale Access Boundary](TAILSCALE-ACCESS.md) for key expiry,
  lost-device response, and recovery requirements.

## SOPS and secret handling

- Store secret values only in SOPS-encrypted files under `secrets/`.
- `.sops.yaml` contains public recipients and creation rules, never private age
  keys or secret values.
- `modules/features/secrets.nix` declares how a secret is materialized; it is
  not where the value is stored.
- Give every host only the encrypted profiles it must decrypt. Separate at
  least interactive AI, HP service/agent, Nextcloud, Syncthing identity, and
  off-site backup credentials.
- Use stable service-specific environment files with the narrowest owner and
  mode possible. Services must not receive the interactive user's entire
  environment.
- Keep password hashes and backup credentials root-only.
- Do not expose service or root-only secrets through the interactive shell
  loader. The loader should use an explicit allowlist rather than scanning all
  files in `/run/secrets`.
- Never interpolate secret contents into Nix derivations, systemd unit text,
  command-line arguments, or journal messages.
- Before committing an encrypted file, inspect the diff and confirm every value
  remains `ENC[...]`.
- Rotate a credential found in plaintext, logs, history, an overly broad SOPS
  profile, or a compromised device. Deploy the replacement before revoking the
  old credential.

See [Secrets Management](SECRETS.md) for operational SOPS instructions.

## Services and containers

- Run network services under dedicated unprivileged users where supported.
- Do not add service users to `wheel`, `docker`, `keys`, `libvirtd`, or personal
  user groups without a documented requirement.
- Bind internal APIs to loopback. Publish only the intended authenticated
  frontend.
- Apply resource and restart limits so one service cannot starve SSH,
  Tailscale, storage, or backups.
- Do not mount the Docker socket into application containers.
- Drop unnecessary Linux capabilities and avoid privileged containers.
- Pin mutable upstream checkouts or container versions and record the deployed
  revision.
- Keep service state outside the dotfiles checkout and explicitly identify
  which state must be backed up.
- Remove unused GUI, printing, Bluetooth, removable-media, and desktop services
  from headless hosts after verifying application dependencies.

### HP agent services

- Hermes must not inherit personal SSH keys, unrestricted home-directory
  access, interactive AI profiles, or Restic credentials.
- Firecrawl credentials must be root/service-readable only.
- Firecrawl and browser-automation endpoints should remain loopback-only unless
  a concrete consumer requires otherwise.
- Never mount the Docker socket into Firecrawl containers.

### Nextcloud

- Store primary data on the dedicated HP filesystem, not S3 or a FUSE mount.
- Only Nextcloud may manipulate its server-side data directory; clients use
  HTTPS, supported clients, or WebDAV.
- Start with Tailscale-only access. Add a hardened public reverse proxy only
  when unmanaged-device access or public shares are required.
- Require Nextcloud MFA for browser sessions and scoped app passwords/tokens
  for desktop, mobile, and WebDAV clients.
- Treat the data directory, database dump, configuration, custom apps/themes,
  and required encryption/recovery keys as one recovery unit.

## Files, synchronization, and backup

- Nextcloud is authoritative for migrated personal files.
- Do not run Syncthing and Nextcloud over the same live directory.
- Keep Syncthing only for explicitly reviewed machine/service export flows.
- Never synchronize live databases, sockets, locks, container layers, caches,
  VM images, `node_modules`, or build outputs.
- A synchronized copy is not a backup: deletion, corruption, or ransomware can
  propagate to every peer.
- Use encrypted Restic snapshots to a dedicated S3 backup bucket with a
  restricted machine identity and separate Restic password.
- Never expose or mount the Restic repository as ordinary file storage.
- Enable bucket public-access blocking, versioning, and provider-side
  encryption in addition to Restic encryption.
- Back up consistent database dumps or quiesced exports, not live database
  files.
- Record backup success separately from source freshness.
- Test clean-cache file, folder, and isolated full-service restoration before
  declaring backup complete or migrating irreplaceable data.
- Do not enable automatic `forget`, `prune`, lifecycle expiration, Object Lock,
  or permanent version deletion until the high-risk retention procedure is
  reviewed.

## Safe change and deployment procedure

Before implementation:

1. Inspect `git status` and preserve unrelated staged, unstaged, and untracked
   work.
2. Resolve the exact host, service, data, identities, ports, and rollback path.
3. Confirm local or LAN recovery access before authentication/firewall changes.
4. Avoid combining security, storage, firmware, and unrelated application
   changes.

Before deployment:

1. Run `git diff --check`.
2. Evaluate and build every affected host closure.
3. Inspect evaluated firewall rules, service bindings, user/group membership,
   and secret ownership rather than assuming module placement is sufficient.
4. Confirm no plaintext secret appears in the diff or evaluated output.
5. Deploy manually to one host at a time, starting with the easiest host to
   recover physically.

After deployment:

1. Test local login and `sudo` before ending the local session.
2. Open a second SSH connection before closing the first.
3. Verify intended LAN and Tailscale paths and confirm prohibited authentication
   methods fail.
4. Check listening sockets and firewall state.
5. Test the affected application and its recovery path.
6. Retain the previous boot generation until validation is complete.

## Incident response

### Lost or stolen client

1. Expire/remove the device from Tailscale.
2. Remove its SSH key and verify rejection.
3. Revoke Nextcloud sessions/app passwords and other application sessions.
4. Rotate any credentials that may have been stored locally.
5. Preserve evidence and record what was exposed.

### Leaked secret

1. Restrict or stop the affected service without deleting evidence.
2. Add a replacement to the correct SOPS profile.
3. Deploy and verify the replacement consumer.
4. Revoke the old credential and confirm it fails.
5. Check Git history, shell history, logs, environment files, and service output
   for further exposure.

### Compromised host or service

1. Isolate its network access while preserving a recovery/admin path.
2. Revoke its Tailscale node, SSH keys, SOPS recipients, and service
   credentials as appropriate.
3. Do not trust backups or exports created after the suspected compromise
   without review.
4. Rebuild from declarative configuration and restore only from a verified
   recovery point.
5. Rotate credentials accessible to the compromised principal.

### Unwanted deletion or corruption

1. Pause the responsible Nextcloud/Syncthing client or service to stop
   propagation.
2. Preserve current state and conflict files rather than immediately merging or
   deleting them.
3. Identify the last known-good Restic snapshot.
4. Restore to an isolated location first, verify contents, then perform the
   controlled recovery.

## Periodic review

Until automated monitoring is intentionally implemented, review these items
manually:

- Weekly: failed services, backup timer/result, latest snapshot, source
  freshness, HP storage capacity, and unexpected listening ports.
- Monthly: pending system/security updates, Nextcloud and container versions,
  Tailscale devices/grants, authorized SSH fingerprints, and active application
  sessions.
- Quarterly: isolated restore test, SOPS recipients, privileged groups,
  firewall exposure, unused services, recovery codes, and documented recovery
  procedures.
- Immediately: investigate unexpected logins, unknown tailnet devices, backup
  failures, secret exposure, storage errors, or unexplained configuration drift.
