# Security, Organization, Sync, and Backup Implementation Plan

Status: Proposed

Created: 2026-07-31
Revised: 2026-08-04

Scope: Low-risk security fixes, configuration organization/deduplication,
self-hosted OpenCloud file access, narrowly scoped machine synchronization,
and encrypted off-site backup for
`workstation`, `lenovo-yoga-pro-7`, and `hp-server`.

Source plans:

- [Security, Monitoring, and Remote Backup](security-monitoring-backup.md)
- [High-Risk Storage, Hibernation, and System Changes](high-risk-storage-hibernation-system-changes.md)

## Objective

Implement the security and backup portions of the source plan without adding
the monitoring stack and without performing any high-risk system or storage
work.

The completed system should have:

- no weak default local password
- key-only SSH with intentional network exposure
- convenient but explicitly scoped SOPS secret profiles
- a manually installed Hermes agent running with a documented security boundary (on HP server only)
- a hardened, loopback-only Firecrawl deployment on HP
- Docker, printing, desktop I/O, monitor control, and device rules owned by the
  correct feature modules instead of `base.nix`
- a publicly reachable OpenCloud service whose files are stored locally on the
  upgraded HP server, published through Cloudflare Tunnel, authenticated by
  Keycloak OIDC with MFA, and usable from browsers, Linux, and Android
- encrypted off-site Restic snapshots from HP to a dedicated S3 backup bucket
- verified restore procedures
- a hybrid personal-file architecture: Syncthing exclusively for the Obsidian
  vault, OpenCloud for documents/media/shared files, GitHub plus HP-managed Git
  mirrors for code, and no overlapping synchronization roots

## Explicitly Deferred

Do not implement any of the following through this plan:

- Prometheus, Grafana, Alertmanager, Node Exporter, external heartbeats, or
  monitoring dashboards
- kernel parameters, initrd changes, swap, hibernation, partitioning, LUKS, or
  filesystem migration
- Restic `forget`, Restic `prune`, S3 lifecycle expiration, Object Lock, or
  permanent deletion of S3 object versions
- SSD discard policy, firmware updates, automatic Nix garbage collection,
  automatic system switching, or automatic reboot
- direct nginx internet ingress, router port-forwarding, and migration away
  from Cloudflare Tunnel; retain these as a later reviewed ingress change
- unrelated application, desktop, or window-manager changes

The backup implementation may write local status files and structured journal
entries for future monitoring, but must not introduce a monitoring service.

## Safety and Working-Tree Rules

- Preserve all unrelated staged, unstaged, and untracked work.
- Inspect the current diff before every implementation phase.
- Stage and commit only a completed phase, and only when explicitly requested.
- Build all affected host configurations before deployment.
- Deploy manually to one host at a time.
- Keep current boot generations available; this plan does not perform cleanup.
- Do not migrate irreplaceable files into OpenCloud until the initial off-site
  backup and isolated restore test have succeeded.
- Do not rotate a credential until every intended consumer has switched to the
  replacement.

## Fixed Architecture Decisions

### Machine roles

| Machine             | Role in this plan                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `workstation`       | Desktop and development host; initial migration source and complete OpenCloud client mirror where capacity permits |
| `lenovo-yoga-pro-7` | Occasionally connected desktop and selective/offline OpenCloud client                                              |
| `hp-server`         | Always-on OpenCloud, Keycloak, and Cloudflare Tunnel host; Restic uploader; manual Hermes/AI-agent and Firecrawl host |

### Data ownership

- The workstation is authoritative only while the initial OpenCloud dataset is
  prepared and migrated. After verified migration, OpenCloud on HP is
  authoritative for `Documents`, `Pictures`, `Music`, and `Shared`.
- Syncthing remains exclusively responsible for the Obsidian `Vault`. HP is an
  always-on peer and Restic backs up the HP vault copy. The vault must not be
  nested inside or selected by any OpenCloud synchronization root.
- Active code repositories are not synchronized by OpenCloud or Syncthing.
  Developers and agents commit and push through Git; HP discovers and validates
  read-only bare mirrors of the GitHub repositories before Restic snapshots them.
  Only committed and pushed code is covered by this centralized backup path.
- `Downloads`, caches, build artifacts, VM images, browser caches,
  `node_modules`, and live application databases are excluded by default.
- Live Hermes state is not synchronized. HP creates a consistent export in a
  dedicated local backup source directory on HP.
- OpenCloud provides file access and synchronization for its assigned durable
  folders. Syncthing provides peer synchronization only for the vault and any
  separately reviewed service exports. Restic/S3 provides independent backup
  history for both authoritative data sets.

### Storage roles and access boundary

S3 is used only for encrypted off-site backup. Never expose the Restic
repository through a mount, file browser, WebDAV, OpenCloud, or mobile client.

| Role                  | Backend                                        | Consumers                                        | Access model                                       |
| --------------------- | ---------------------------------------------- | ------------------------------------------------ | -------------------------------------------------- |
| General primary files | dedicated local filesystem on HP               | OpenCloud server                                 | service-account-only local access                  |
| General file access   | OpenCloud on HP through Cloudflare Tunnel      | browser, Linux, Android                          | public HTTPS, OIDC MFA, and per-client app tokens   |
| Obsidian vault        | Syncthing folder with HP as always-on peer     | workstation, Lenovo, Android, HP                 | paired Syncthing devices only                      |
| Active code           | GitHub plus read-only bare mirrors on HP       | developers, agents, HP backup service            | Git push/fetch; never OpenCloud or Syncthing       |
| Off-site backup       | dedicated `restic-backup` S3 bucket and prefix | root-run Restic on HP; recovery environment only | restricted machine credential plus Restic password |

OpenCloud architecture:

- Run the native NixOS `services.opencloud` module on HP with the complete
  `pkgs-unstable.opencloud` package family and use its pure-POSIX storage mode.
  Keep all OpenCloud state on the upgraded local filesystem, not in S3 and not
  on a FUSE/network mount. S3 remains backup-only.
- Give the `opencloud` service exclusive access to its state tree. OpenCloud
  stores file metadata in extended attributes or sidecar metadata; users and
  other synchronization tools must access files through OpenCloud clients,
  WebDAV, or the API rather than editing the server-side tree.
- Publish `cloud.<domain>` and the required `auth.<domain>` OIDC endpoints
  through one Cloudflare Tunnel. `cloudflared` creates outbound-only connections
  from HP, so OpenCloud, the identity-provider backend, and router ports remain
  closed to unsolicited inbound traffic.
- Use Keycloak as the required OpenID Connect identity provider in an
  OpenCloud-supported user-directory mode and enforce MFA there. Keep the
  built-in OpenCloud IDP disabled for routine login. Keep Keycloak/OpenCloud
  administrative access on Tailscale where the applications permit it.
- Do not put Cloudflare Access in front of the OpenCloud or OIDC hostnames; its
  additional browser login can break desktop, Android, WebDAV, and OIDC flows.
  Configure Cloudflare to bypass caching for both hostnames.
- Use the official OpenCloud desktop and Android clients for sync, uploads,
  offline access, and sharing. WebDAV clients use distinct revocable app tokens,
  never the account password.
- Treat the OpenCloud state directory, `/etc/opencloud`, generated identity and
  service keys, custom web-app assets, and the pinned OpenCloud version as one
  recovery unit. Capture them only while OpenCloud is stopped or from a tested
  read-only filesystem snapshot created while it is stopped.

This is a service, not a shared server-side folder. Unlike the previous
Nextcloud design, the selected single-binary pure-POSIX deployment does not add
PHP-FPM, a SQL database, or Redis. It still requires upgrades, access controls,
consistent backups, restore tests, and later monitoring. Keycloak runs with its
own database and the selected OpenCloud-supported directory integration; treat
that authentication stack as a separate recovery unit rather than claiming the
entire public service has no database.

### Authentication boundary

- Keycloak is the sole interactive identity provider for OpenCloud users and
  administrators in this architecture.
- Keycloak owns password policy, MFA enrollment/challenges, sessions, recovery
  codes, and interactive account lockout. OpenCloud consumes Keycloak-issued
  OIDC tokens and retains authorization/role behavior required by OpenCloud.
- OpenCloud's built-in IDP is disabled for routine authentication. It is not a
  fallback login path that bypasses Keycloak MFA.
- Cloudflare Tunnel provides ingress only; Cloudflare Access is not an
  additional authentication layer.
- OpenCloud app tokens remain the explicit exception for WebDAV or clients that
  cannot use OIDC. Issue one expiring token per client and revoke it when the
  device is retired or lost.

### Backup targets

- Remote-backup RPO target: 36 hours while HP has power and
  network access.
- Single-file restore target: within 1 hour.
- Critical-folder restore target: within 8 hours, subject to provider/network
  throughput.
- The first implementation is append-only from an operational perspective:
  create snapshots and normal transient Restic locks, but automate no snapshot
  or repository-data deletion.

## Phase 0: Pre-Implementation Decisions and Baseline

### Required user decisions

- [ ] Complete the separately authorized HP RAM/storage upgrade, then record
      the dedicated OpenCloud data mount, filesystem, capacity, ownership, health
      checks, and replacement/recovery procedure. Do not perform partitioning or
      filesystem migration implicitly through this plan.
- [ ] Choose an S3-compatible backup provider, region, `restic-backup` bucket
      name, and expected storage/retrieval budget.
- [ ] Confirm the local-storage OpenCloud architecture and which folders need
      complete offline copies on workstation and Lenovo.
- [ ] Register a custom domain, place its DNS zone in Cloudflare, and choose the
      final `cloud.<domain>` and `auth.<domain>` names. Create a locally managed
      Cloudflare Tunnel and record its UUID and recovery procedure.
- [ ] Choose the Keycloak MFA method, OpenCloud-supported user-directory mode,
      recovery-code custody, and break-glass identities before public exposure.
- [ ] Accept Cloudflare's proxy/privacy dependency and plan limits for the
      initial deployment. Test uploads above the plan's per-request limit; if
      client chunking is insufficient, migrate the same hostnames to direct
      nginx ingress in a separate later phase.
- [ ] Choose separate strong local passwords for the three hosts.
- [ ] Confirm which SSH public keys are still valid.
- [ ] Confirm the actual printer model and whether driverless IPP works.
- [ ] Confirm Docker is required on workstation and HP, but not Lenovo.
- [ ] Confirm the stable path and manual installation/update procedure for the
      Hermes executable.

### Record the current state

- [ ] Record current host builds and active boot generations.
- [ ] Record listening ports and the interfaces on which they listen.
- [ ] Record Tailscale node names, Syncthing device IDs, and SSH access paths.
- [ ] Record current Syncthing folder health and folder sizes before retiring
      overlapping personal-file shares.
- [ ] Record available space on all three machines, usable and replaceable HP
      storage, dataset size, growth allowance, and estimated off-site backup size.
- [ ] Record which HP desktop packages or services are actually required by
      Hermes or browser automation.
- [ ] Make one test print and scan if the printer/scanner is currently available.

Deliverable: a short implementation note containing the selected provider,
backup identity, HP storage layout, OpenCloud access boundary,
expected cost, printer driver choice, valid SSH keys, Docker host list, and
Hermes path.

## Phase 1: Configuration Ownership and Deduplication

This phase moves existing behavior to the module that owns it. It should not
change user-visible behavior on workstation or Lenovo.

### 1.1 Slim `base.nix`

File:

- `modules/base.nix`

Remove from the base module:

- `virtualisation.docker.enable`
- `services.printing.enable` (printing is a feature module in printing.nix)
- `services.gvfs.enable`
- `programs.gnome-disks.enable`
- `ddcutil`, monitor I2C group/rules, and other external-monitor-only wiring
- the Vial-specific HID rule

Keep only genuinely host-independent system defaults and essential packages in
`base.nix`.

Acceptance:

- HP no longer receives GUI/storage/monitor peripheral behavior merely by
  importing `base`.
- Workstation and Lenovo retain required behavior through explicit features.

### 1.2 Give each feature one owner

Files:

- add `modules/features/system/docker.nix`
- `modules/features/system/printer.nix`
- `modules/features/system/external-io.nix`
- `modules/features/desktop/desktop-common.nix`
- `modules/features/desktop/brightness-external.nix`
- `modules/features/applications/vial.nix`
- host configurations

Actions:

- [ ] Create a small Docker feature that owns Docker enablement.
- [ ] Import Docker explicitly on HP and workstation only, unless the Phase 0
      inventory proves Lenovo needs it.
- [ ] Remove `docker` group membership on hosts where Docker is disabled.
- [ ] Make the printer feature the sole owner of CUPS, scanning, IPP-over-USB,
      Avahi printer discovery, and printer/scanner group membership.
- [ ] Keep the printer feature on workstation and Lenovo; remove it from HP
      unless HP is intentionally acting as a print server.
- [ ] Prefer driverless IPP. Retain only the legacy vendor driver needed by the
      actual printer, rather than the full generic vendor list.
- [ ] Keep UDisks in `externalIo`; move GVFS and GNOME Disks to desktop-specific
      configuration.
- [ ] Move DDC/I2C permissions and `ddcutil` to the external-brightness feature,
      imported only where the physical monitor needs it.
- [ ] Move the Vial HID rule into the Vial feature.

Acceptance:

- There is exactly one declarative owner for Docker, printing, GVFS,
  external-monitor control, and Vial permissions.
- Workstation can print, scan, mount removable media, control the external
  monitor, and use Vial as before.
- Lenovo can print, scan, and mount removable media as before.
- HP has none of those desktop/peripheral services unless explicitly retained.

### 1.3 Remove stale inputs and auto-imported dead modules

Files:

- `flake.nix`
- `flake.lock`
- `modules/features/ai/DEPRECATED-hermes-agent/`
- documentation referencing deprecated modules

Actions:

- [ ] Confirm `vscode-server` is unused, then remove its input.
- [ ] Confirm the Hermes flake input is used only by the deprecated declarative
      installer, then remove that input.
- [ ] Remove or move the deprecated Hermes Nix module out of the auto-imported
      `.nix` tree while preserving any still-useful operational documentation.
- [ ] Refresh the lock file only for inputs intentionally removed; do not
      upgrade unrelated inputs in the same change.

Acceptance:

- Manual Hermes remains supported and documented.
- Evaluating the flake no longer requires the unused Hermes or VS Code Server
  inputs.
- No unrelated dependency revision changes are mixed into the cleanup.

## Phase 2: Local Accounts, SSH, and Tailnet Security

### 2.1 Remove the weak installation password

Files:

- `modules/users/henhal.nix`
- `modules/features/secrets.nix`
- `.sops.yaml`
- host-scoped password SOPS files

Actions:

- [ ] Remove `initialPassword = "password"`.
- [ ] Create separate host-scoped password-hash secrets.
- [ ] Use `hashedPasswordFile` for new installations without changing
      `users.mutableUsers` in this low-risk plan.
- [ ] Verify local login and sudo before touching SSH or firewall settings.
- [ ] Do not remove the current local password until its replacement has been
      tested on that host.

Acceptance:

- A fresh installation has no known default password.
- Existing local login and sudo remain functional on every deployed host.
- No plaintext password appears in Git, the Nix store, process arguments, or
  activation logs.

### 2.2 Audit SSH authorization and defaults

Files:

- `modules/users/henhal.nix`
- `modules/features/network/ssh-server.nix`
- `modules/features/network/ssh-config.nix`

Actions:

- [ ] Remove obsolete authorized keys and give each retained key an accurate
      device comment.
- [ ] Keep `PasswordAuthentication = false` and `PermitRootLogin = "no"`.
- [ ] Explicitly disable keyboard-interactive authentication.
- [ ] Enable PAM account/session handling while retaining key-only login.
- [ ] Remove custom cipher and key-exchange lists unless an active client
      requires one; use maintained OpenSSH defaults.
- [ ] Reduce fail2ban retry limits to a meaningful value on LAN-reachable SSH,
      or omit fail2ban where SSH is reachable only through Tailscale.
- [ ] Remove stale SSH host aliases and hardcoded addresses after testing their
      replacement.

Acceptance:

- All retained workstation, Lenovo, HP, and Android access paths work.
- Password, keyboard-interactive, and root SSH login fail.
- Removing one test authorization key reliably revokes that key.

### 2.3 Replace blanket Tailscale trust

Files:

- `modules/features/network/tailscale.nix`
- host configurations
- external tailnet ACL/policy documentation

Actions:

- [ ] Remove blanket firewall trust for `tailscale0`.
- [ ] Declare only the required per-interface ports for SSH, Syncthing, and the
      HP services retained in this plan.
- [ ] Do not open future monitoring ports yet.
- [ ] Define tailnet tags/ACLs so HP service access, administrative access, and
      ordinary device access are distinct.
- [ ] Document how to revoke a lost device and how device-key expiry is handled.
- [ ] Preserve a tested local-console or LAN break-glass path before narrowing
      remote access.

Acceptance:

- Required LAN and Tailscale SSH paths still work.
- An unauthorized tailnet device cannot reach HP administration services.
- Removing Tailscale connectivity does not eliminate all recovery access.

## Phase 3: Practical Secret Profiles

### 3.1 Split secrets into intentional scopes

Files:

- `modules/features/secrets.nix`
- `.sops.yaml`
- `secrets/shared-interactive.yaml`
- `secrets/hp-agent.yaml`
- `secrets/hp-backup.yaml`
- `secrets/opencloud.yaml`
- existing host-specific Syncthing secret files

Profiles:

| Profile               | Recipients                                | Owner/mode                                     | Contents                                                        |
| --------------------- | ----------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------- |
| Shared interactive AI | personal keys plus hosts that use AI CLIs | `henhal`, `0400`                               | intentionally interactive provider credentials                  |
| HP agent services     | personal keys plus HP                     | dedicated Hermes user or service owner, `0400` | Hermes, Telegram, Firecrawl and agent-only credentials          |
| OpenCloud stack       | personal keys plus HP                     | separate OpenCloud, Keycloak, and root-only files, `0400` | OpenCloud service, Keycloak/OIDC, MFA bootstrap, and Cloudflare Tunnel credentials |
| HP backup             | personal keys plus HP                     | `root`, `0400`                                 | Restic repository password and restricted S3 backup credentials |

Actions:

- [ ] Replace wildcard loading of every `/run/secrets` file with one generated,
      allowlisted `interactive-ai.env`.
- [ ] Continue sourcing that file automatically in interactive shells.
- [ ] Generate stable service-specific environment files from SOPS at
      activation time; do not manually decrypt on login or service start.
- [ ] Ensure backup secrets are never exported to an interactive shell.
- [ ] Ensure only root on HP can read backup credentials; the OpenCloud,
      Hermes, Firecrawl, and interactive users cannot read them.
- [ ] Ensure the OpenCloud service account can read only its own service
      secrets and cannot read the Restic/S3 backup credentials.
- [ ] Keep the Cloudflare Tunnel credential root-only and inject it through
      systemd credentials. Do not store the Cloudflare account certificate or
      a broad API token on HP when a tunnel-scoped credential is sufficient.
- [ ] Ensure OpenCloud cannot read Keycloak administrative/database secrets and
      Keycloak cannot read the Cloudflare Tunnel or Restic/S3 credentials.
- [ ] Ensure Lenovo cannot decrypt HP agent-service credentials.
- [ ] Prevent secret values from appearing in unit definitions, journal output,
      command arguments, metrics, or debug logs.

Acceptance:

- Interactive AI tools work immediately in a new shell.
- Manual Hermes startup requires no SOPS command.
- Each host decrypts only the profiles it intentionally consumes.
- No secret-bearing generated file is group/world-readable.

### 3.2 Rotate broadly exposed credentials

Rotate only after all new consumers are deployed:

- [ ] Firecrawl/OpenAI credential previously written to a `0644` file.
- [ ] Hermes/Telegram credentials that were available on unnecessary hosts.
- [ ] Any API credential found in shell history, logs, or obsolete environment
      files during validation.

For each rotation:

1. Add the replacement to the correct SOPS profile.
2. Deploy and verify the consumer.
3. Revoke the previous credential.
4. Verify the old credential fails.
5. Record the rotation date and scope without recording the value.

## Phase 4: HP Agent and Firecrawl Security

### 4.1 Separate the agent runtime from the interactive account

Files:

- add `modules/features/ai/hermes-runtime.nix`
- `hosts/hp-server/configuration.nix`
- HP agent SOPS profile

Actions:

- [ ] Create a dedicated `hermes-agent` system user and state directory.
- [ ] Do not add it to `wheel`, `docker`, `keys`, `libvirtd`, or the interactive
      user's groups.
- [ ] Keep Hermes installation manual, performed as the service user into its
      stable state/home path.
- [ ] Let NixOS manage the user, directories, secret environment file,
      dependencies, and optional systemd supervisor—not the Hermes package.
- [ ] Give the service explicit read/write paths rather than the complete
      `/home/henhal` tree.
- [ ] Apply `NoNewPrivileges`, private temporary storage, restart limits,
      `TasksMax`, `MemoryMax`, and a CPU quota that leaves SSH, Tailscale,
      Syncthing, and Firecrawl responsive.
- [ ] Add a pre-start check that explains how to repair a missing/incompatible
      manual executable.
- [ ] Provide one documented maintenance command for opening a shell as the
      service user with its environment loaded.

Fallback: if upstream Hermes cannot operate under a dedicated account, stop
and document the precise blocker before choosing to run it as `henhal`. Do not
silently grant the agent interactive-user, Docker, SSH-key, or SOPS access.

Acceptance:

- Hermes runs from the manual installation path under the dedicated account.
- Hermes has its intended API credentials but cannot read HP backup
  credentials, personal SSH keys, or unrelated SOPS outputs.
- Agent resource exhaustion cannot starve remote administration.

### 4.2 Harden Firecrawl and repair its Git layout

Files:

- `modules/features/ai/firecrawl/default.nix`
- `modules/features/ai/firecrawl/firecrawl-compose.yml`
- `.firecrawl-src` Git-link entry
- `.gitignore` if needed

Actions:

- [ ] Remove the orphaned `.firecrawl-src` Git-link entry.
- [ ] Do not add Firecrawl as a submodule.
- [ ] Move the mutable upstream checkout to `/var/lib/firecrawl/source`.
- [ ] Pin the upstream revision through a declared option or version file.
- [ ] Make bootstrap fetch that revision and fail clearly without modifying the
      dotfiles checkout.
- [ ] Render `firecrawl.env` as root-owned `0400`.
- [ ] Bind the Firecrawl API to `127.0.0.1` when only local Hermes consumes it.
- [ ] Remove the host-published Playwright port unless a verified external
      consumer needs it.
- [ ] Do not mount the Docker socket into Firecrawl containers.
- [ ] Drop unnecessary capabilities and set container CPU, memory, process,
      restart, and log-size limits.
- [ ] Record the deployed revision in the journal on startup.

Acceptance:

- A fresh dotfiles clone contains no broken submodule/Git-link state.
- Firecrawl starts from the pinned checkout outside the repository.
- Hermes reaches Firecrawl over loopback.
- Firecrawl and Playwright are not reachable from LAN or Tailscale.
- Firecrawl cannot read unrelated secret profiles.

### 4.3 Reduce unrelated HP desktop surface

Files:

- `hosts/hp-server/configuration.nix`

After confirming agent dependencies, remove from HP:

- SDDM and Niri
- graphical desktop foundation and launchers
- GUI browsers and office/media applications not required for automation
- PipeWire, Bluetooth, printing, scanner, and removable-media GUI services
- virtualization unless an active agent workload requires it

Keep:

- SSH, Tailscale, Syncthing, Docker, Firecrawl, Git, tmux, required runtimes,
  manual Hermes support, SOPS, and command-line administration tools

Do not remove Hermes Dashboard, Hermes Workspace, or browser-automation
dependencies until their current use has been tested explicitly.

Acceptance:

- HP boots to `multi-user.target`.
- Hermes and Firecrawl still pass functional tests.
- No removed desktop service remains active or listening.

## Phase 5: Establish Hybrid File Access and Off-Site Backup Before Migration

### Hybrid ownership boundary

Use exactly one live synchronization owner for each data class:

| Data                                                     | Owner and transport                         |
| -------------------------------------------------------- | ------------------------------------------- |
| Obsidian `Vault`, including attachments stored inside it | Syncthing only                              |
| `Documents` and ordinary PDFs outside the vault          | OpenCloud                                   |
| `Pictures`, phone uploads, `Music`, and `Shared`         | OpenCloud                                   |
| Committed and pushed code repositories                   | GitHub plus HP-managed bare Git mirrors     |
| Live Hermes state                                        | HP-local only; consistent export for Restic |
| Off-site recovery history                                | Restic from HP to S3                        |

Do not configure OpenCloud and Syncthing against the same directory, nested
directories, or alternate paths resolving to the same files. In particular,
keep `Vault` outside `Documents` before enabling the OpenCloud desktop client.
OpenCloud and Syncthing are synchronization systems, not backups.

Local working trees remain ordinary Git clones. Uncommitted changes, untracked
files, ignored files, local-only branches, and commits that have not been pushed
are not covered by the centralized code-backup path. Developers and agents must
commit and push work-in-progress branches before switching machines or ending a
work session. HP mirrors GitHub; it does not synchronize live working trees.

**Obsidian vault stays on Syncthing, not OpenCloud, in all configurations.**
OpenCloud's desktop client can synchronize local folders, but its Android app
is primarily a cloud file/offline-file client rather than a dependable
background two-way synchronizer for an arbitrary Obsidian folder. Android
battery and lifecycle restrictions therefore remain relevant. Syncthing keeps
a normal, fully materialized vault directory on every peer and HP remains the
always-on convergence peer. OpenCloud does not remediate the vault-drift problem
by itself, so this ownership decision does not change.

- [ ] Add a Syncthing ignore pattern for `.obsidian/workspace.json` and
      `.obsidian/workspace-mobile.json` on any vault synced to more than one
      device. These store per-device window/pane layout; syncing them causes
      UI-state churn and spurious conflict copies unrelated to note content.
- [ ] Expect conflict-copy files (`filename (conflicted copy ...).ext`) as
      normal Syncthing/OpenCloud behavior when the same file is edited on two
      devices before a sync completes. This is expected behavior to review
      periodically, not a fault condition to alarm on.

### Effect of replacing Nextcloud with OpenCloud

The ownership boundary does not change:

- Syncthing remains the exclusive owner of the Obsidian vault.
- OpenCloud replaces Nextcloud only for `Documents`, `Pictures`, `Music`, and
  `Shared`.
- Git/GitHub mirrors remain the code transport and centralized code backup
  source; neither file synchronizer owns active repositories.
- Restic remains required. OpenCloud versions, trash, and client synchronization
  cannot protect against HP storage failure, service corruption, account
  compromise, or propagated deletion, and they do not provide an off-site copy.
- Hermes stays HP-local and enters Restic only through a consistent export.

What does change is OpenCloud's recovery unit. There is no Nextcloud SQL dump,
Redis state, PHP-FPM, or maintenance-mode sequence. OpenCloud's configuration,
system data, file blobs, and metadata form one filesystem recovery unit. The
[OpenCloud backup guide](https://docs.opencloud.eu/docs/admin/maintenance/backup/)
requires OpenCloud to be stopped before a consistent backup or storage snapshot
is taken.

Phase 5 issue register:

| Issue | Effect on the plan | Required disposition |
| --- | --- | --- |
| Stable package is OpenCloud 3.7.0 while `pkgs-unstable.opencloud` is 7.3.0 | Setting only `package` would retain stable web/IDP assets and create a mixed package family | Set `package`, `webPackage`, and `idpWebPackage` from `pkgs-unstable.opencloud` and record all evaluated versions |
| Built-in IDP has no MFA | It does not satisfy the public-service boundary | Disable it for routine login and use Keycloak OIDC with enforced MFA |
| The NixOS Keycloak module defaults do not match the tunnel origin | The module defaults to a non-loopback listener and a different HTTP port, while the tunnel targets `127.0.0.1:8080` | Set the Keycloak listener, port, public hostname, HTTP edge-termination mode, proxy headers, and trusted proxy addresses explicitly |
| OpenCloud metadata uses xattrs/sidecars | An ordinary file-only copy may restore content but break service metadata | Back up the complete stopped state and verify xattr round-trip in an isolated restore |
| Consistency requires a stopped service | Live Restic reads are not valid | Use a stopped-service filesystem snapshot or an offline backup window |
| Optional web apps lack a NixOS `extraApps` option | Manual downloads create mutable, unpinned state | Start without optional apps; pin compatible assets in the Nix store when justified |
| Cloudflare Tunnel is an external proxy and privacy dependency | Cloudflare carries and terminates public HTTPS traffic | Bypass caching, keep files on HP, protect the tunnel credential, and document later direct-nginx migration |
| Cloudflare Free/Pro limits a proxied request body to 100 MB | A client that does not chunk a large upload can fail with HTTP 413 | Test browser, Android, desktop, and WebDAV uploads above 100 MB before migration |
| Cloudflare Access adds a second authentication gateway | Browser-oriented Access policy can break native client, WebDAV, or OIDC redirects | Do not enable Access on the OpenCloud or OIDC hostnames; enforce MFA in Keycloak |
| Android OpenCloud is not the selected Obsidian folder synchronizer | It does not solve Android background vault convergence | Retain the non-overlapping Syncthing vault with HP as always-on peer |
| OpenCloud synchronization and versions are not off-site backup | Deletion/corruption can propagate and HP remains one failure domain | Retain encrypted Restic snapshots to the dedicated S3 bucket |
| The OpenCloud filesystem is an external USB T7 | Cable, enclosure, power, or accidental removal can make the data mount disappear while the HP host remains online | Mount by UUID, require the mount for OpenCloud and Restic, fail closed without a root-directory fallback, record the physical replacement path, and test disconnect/reconnect behavior |
| A local Restic repository on the T7 shares the OpenCloud disk failure domain | It can provide recovery convenience but cannot protect against loss of the T7 or HP | Keep S3 as the independent Restic destination and label any local copy as staging only |
| The selected T7 ext4 filesystem is currently unencrypted | Physical removal of the portable SSD exposes OpenCloud data | Make LUKS2 versus documented physical-security controls an explicit pre-production decision; keep key recovery separate from the disk |
| An auxiliary exporter can fail independently of OpenCloud | A hard preparation dependency could let GitHub, Hermes, identity, or vault refresh failure suppress current file backups | Preserve last validated auxiliary sources, mark them degraded, and continue backing up other coherent sources |
| Syncthing `idle` is only a momentary status | A write can arrive after the check while Restic reads the live vault | Stop Syncthing after an idle/zero-pending check and atomically publish a staged snapshot or copy |
| `git fsck` does not validate Git LFS payloads | A mirror can pass Git validation while required large objects are absent or corrupt | Validate LFS OIDs and payload hashes across every mirrored ref separately |
| Restic removes transient lock objects during normal operation | A literal ban on all repository-object deletion is incompatible with a functioning Restic client | Permit transient lock deletion while prohibiting automated snapshot, pack, index, and noncurrent-version deletion |

### 5.1 Provision public OpenCloud through Cloudflare Tunnel

Files:

- add `modules/features/cloud/opencloud.nix`
- add `modules/features/network/cloudflare-tunnel.nix`
- add `modules/features/auth/keycloak.nix` using NixOS `services.keycloak`, its
  local PostgreSQL database, and the reviewed OpenCloud user-directory
  integration
- add `secrets/opencloud.yaml` and its `.sops.yaml` creation rule
- update `modules/features/secrets.nix` with consumer-specific OpenCloud,
  Keycloak, and Cloudflare Tunnel secrets/templates
- update `hosts/hp-server/configuration.nix` to import/enable the feature
- add `docs/runbooks/opencloud-recovery.md` during Phase 7

#### Version and module gate

The current stable host package is OpenCloud `3.7.0`; the flake's
`nixpkgs-unstable` input provides OpenCloud server `7.3.0`. The HP NixOS
configuration already receives that package set as the `pkgs-unstable` special
argument. Select the complete asset family rather than overriding only the
server executable:

```nix
services.opencloud = {
  package = pkgs-unstable.opencloud;
  webPackage = pkgs-unstable.opencloud.web;
  idpWebPackage = pkgs-unstable.opencloud.idp-web;
};
```

- [ ] Record the evaluated server, web, and IDP-web versions. The web asset's
      own version may differ from the server version; using every component from
      the same `pkgs-unstable.opencloud` attribute family is the compatibility
      boundary. Do not force matching version strings manually.
- [ ] After enabling the module, verify the selected server package with:

      ```console
      nix eval --raw \
        .#nixosConfigurations.hp-server.config.services.opencloud.package.version
      ```

- [ ] Record `services.opencloud.stateDir`, the evaluated package version, the
      exact user-storage path beneath the state directory, and the output of
      `systemctl cat opencloud.service` in the recovery runbook.
- [ ] Run `opencloud init --diff` or the matching version's non-destructive
      configuration check before every OpenCloud package upgrade.

The native NixOS module already supplies the `opencloud` user, hardened systemd
service, loopback address, package, web assets, state-directory option, and
secret environment-file hook. Use it instead of Docker Compose. Base the module
on the [NixOS OpenCloud guide](https://wiki.nixos.org/wiki/OpenCloud), then
verify every option against the flake's evaluated module rather than copying a
configuration for another Nixpkgs revision.

#### Storage layout

Use one pure-POSIX local deployment. S3 is not an OpenCloud storage backend:

```text
/srv/opencloud/                  dedicated HP filesystem and mountpoint
  state/                        services.opencloud.stateDir
  backup-staging/               root-only consistent config/manifest staging
  .snapshots/                   only if the existing filesystem supports snapshots
/etc/opencloud/                 generated and declarative service configuration
/run/secrets-rendered/
  opencloud-env                 runtime secrets; never copied to the Nix store
```

##### Verified HP data disk

The dedicated local filesystem selected for this phase is a Samsung PSSD T7
external USB SSD, not the internal Windows SSD previously visible on the
workstation. Its current identity and baseline are:

- raw capacity: `931.5G` (marketed as 1 TB), with approximately `916G`
  filesystem capacity and `870G` free after formatting
- one `ext4` filesystem labelled `cloud-ssd`
- filesystem UUID:
  `e4577487-f1c0-4aee-bea3-daac8df1633d`
- observed T7 serial: `S6XDNS0WA22565Z`
- tested HP device path: `/dev/sda1`; this path is not stable and must not be
  used by the service configuration

The filesystem was mounted read-write at `/mnt/cloud-ssd` on HP, inspected,
and unmounted successfully. That mountpoint was only a validation mount; the
production mount is `/srv/opencloud`. HP is headless and does not run UDisks,
so the production mount and service ordering must be provided by NixOS and
systemd rather than desktop automount or `udisksctl`.

- [ ] Mount `/srv/opencloud` by stable identifier before the service starts and
      require `ConditionPathIsMountPoint=/srv/opencloud`. OpenCloud must fail
      closed rather than write into the HP root filesystem when the data disk is
      absent.
- [ ] Configure the filesystem by UUID
      `e4577487-f1c0-4aee-bea3-daac8df1633d`, never by `/dev/sda` or `/dev/sda1`.
- [ ] Treat the T7 as a removable USB dependency: record the physical USB port,
      cable, serial, replacement procedure, and the clean unmount/power-off
      procedure before putting authoritative data on it.
- [ ] Use `services.opencloud.stateDir = "/srv/opencloud/state"`. Keep
      `/srv/opencloud/backup-staging` root-only and outside all client-visible
      spaces.
- [ ] Confirm the filesystem supports user extended attributes and that mount
      options do not disable them. The default PosixFS driver stores metadata in
      xattrs and, when required, sidecar metadata files; preserve both as
      described by the
      [PosixFS documentation](https://docs.opencloud.eu/docs/next/admin/configuration/storage/storage-posix/).
- [ ] Do not edit, browse, index, export over SMB/NFS, or point Syncthing at the
      server-side state tree. Import and migrate files through an OpenCloud
      client, WebDAV, or a supported API.
- [ ] Measure dataset size plus growth, OpenCloud metadata, snapshot headroom,
      Restic cache/staging, and one isolated restore. Reserve explicit free
      space for USB/filesystem failure recovery and do not treat the initial
      `870G` free-space figure as the user-data capacity budget.
- [ ] Do not count a local Restic repository on the T7 as an independent
      backup. Any local copy shares the OpenCloud data disk's failure domain;
      the encrypted S3 repository remains the off-site recovery copy.
- [ ] Verify xattr create/read/delete round-trips on the mounted T7 before
      enabling OpenCloud PosixFS. Ext4 is currently unencrypted; decide before
      production whether this removable disk requires a separately authorized
      LUKS2 layer and record the recovery-key procedure if it does.

Illustrative module body, to be adapted to the reviewed hostname and existing
feature-module style:

```nix
{ config, lib, pkgs-unstable, ... }:
let
  cloudHost = "cloud.example.com";
  authHost = "auth.example.com";
in {
  services.opencloud = {
    enable = true;
    package = pkgs-unstable.opencloud;
    webPackage = pkgs-unstable.opencloud.web;
    idpWebPackage = pkgs-unstable.opencloud.idp-web;
    stateDir = "/srv/opencloud/state";
    address = "127.0.0.1";
    port = 9200;
    url = "https://${cloudHost}";
    environment = {
      OC_INSECURE = "true"; # TLS terminates at Cloudflare's public edge.
      PROXY_TLS = "false";
      OC_OIDC_ISSUER = "https://${authHost}/realms/opencloud";
      OC_EXCLUDE_RUN_SERVICES = "idp";
      PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD = "jwt";
      PROXY_OIDC_REWRITE_WELLKNOWN = "true";
    };
    environmentFile = config.sops.templates."opencloud-env".path;
  };

  systemd.services.opencloud = {
    requiresMountsFor = [ "/srv/opencloud" ];
    unitConfig.ConditionPathIsMountPoint = "/srv/opencloud";
  };

  sops.secrets.OPENCLOUD_ADMIN_PASSWORD = {
    sopsFile = ../../../secrets/opencloud.yaml;
    owner = "opencloud";
    group = "opencloud";
    mode = "0400";
  };
  sops.templates."opencloud-env" = {
    owner = "opencloud";
    group = "opencloud";
    mode = "0400";
    content = ''
      IDM_ADMIN_PASSWORD=${config.sops.placeholder.OPENCLOUD_ADMIN_PASSWORD}
    '';
  };
}
```

The real module must contain no literal password, generated signing key, or
service secret. Confirm the chosen OpenCloud version's required secret list;
the admin password above is the minimum initial example, not a declaration that
it is the only recovery secret. Complete the Keycloak OIDC configuration with
the exact web, desktop, Android, and iOS client IDs/scopes, claims, role mapping,
WebFinger discovery, user-directory mode, and CSP required by OpenCloud 7.3.

#### Cloudflare Tunnel ingress

Cloudflare Tunnel is the initial reverse proxy. It gives remote devices normal
public HTTPS URLs while `cloudflared` makes only outbound connections from HP.
Do not enable nginx, open router ports, or bind OpenCloud/Keycloak to public
interfaces in this phase.

Provider-side bootstrap:

- [ ] Register the custom domain and delegate its DNS zone to Cloudflare.
- [ ] Create one locally managed tunnel named for HP/OpenCloud from a trusted
      administrative workstation. Record its UUID.
- [ ] Store the tunnel-scoped credentials JSON in SOPS, delete the plaintext
      bootstrap copy, and deploy it root-only. Do not retain Cloudflare's broad
      account certificate (`cert.pem`) or an account-wide API token on HP merely
      to run an existing tunnel.
- [ ] Route `cloud.<domain>` and `auth.<domain>` to that tunnel. Manage these
      two external DNS routes in the Cloudflare dashboard or from the trusted
      workstation; document this provider-side state because it is not recovered
      by rebuilding HP alone.
- [ ] Add a Cloudflare cache rule that bypasses caching for both hostnames. Do
      not enable Cloudflare Access, HTML/JavaScript transformations, or a second
      login policy on either hostname.
- [ ] Keep HP's WAN/LAN firewall closed for ports `80`, `443`, `8080`, and
      `9200`. Only the local `cloudflared` process connects to the loopback
      OpenCloud and Keycloak listeners.

Use the native NixOS `services.cloudflared` module. Its systemd unit loads the
tunnel JSON as a credential and runs as a dynamic user:

```nix
{ config, ... }:
let
  tunnelId = "<cloudflare-tunnel-uuid>";
  cloudHost = "cloud.example.com";
  authHost = "auth.example.com";
in {
  sops.secrets.CLOUDFLARED_TUNNEL_CREDENTIALS = {
    sopsFile = ../../../secrets/opencloud.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      credentialsFile =
        config.sops.secrets.CLOUDFLARED_TUNNEL_CREDENTIALS.path;
      ingress = {
        "${cloudHost}" = {
          service = "http://127.0.0.1:9200";
          originRequest.httpHostHeader = cloudHost;
        };
        "${authHost}" = {
          service = "http://127.0.0.1:8080";
          originRequest.httpHostHeader = authHost;
        };
      };
      default = "http_status:404";
    };
  };
}
```

This example intentionally omits `services.cloudflared.certificateFile`:
running a previously created tunnel needs only its scoped credentials JSON.
Cloudflare describes Tunnel as an outbound-only connector with no public IP or
inbound ports required:
[Cloudflare Tunnel](https://developers.cloudflare.com/tunnel/).

#### OIDC and MFA

The Cloudflare Tunnel origin and Keycloak listener are one reviewed contract.
Do not rely on the NixOS Keycloak module defaults: in the pinned module they do
not select the loopback port used by the tunnel. Configure at least the
following settings, using the selected realm and hostname:

```nix
services.keycloak = {
  enable = true;
  database = {
    type = "postgresql";
    createLocally = true;
  };
  settings = {
    http-enabled = true;
    http-host = "127.0.0.1";
    http-port = 8080;
    hostname = "https://${authHost}";
    proxy-headers = "xforwarded";
    proxy-trusted-addresses = "127.0.0.1/32,::1/128";
  };
};
```

The exact option names must be rechecked against the evaluated Keycloak module
and package before implementation. `cloudflared` must overwrite the trusted
`X-Forwarded-*` values rather than append attacker-supplied values. Keep the
Keycloak management port off the tunnel, and do not expose it through the host
firewall.

- [ ] Deploy Keycloak declaratively in a mode supported by the selected
      OpenCloud version. Select and document shared-directory versus
      autoprovisioning behavior before creating real users; do not improvise a
      migration between identity modes after file ownership exists.
- [ ] Publish the OIDC endpoints at `https://auth.<domain>` through the same
      tunnel. Configure the exact OpenCloud web, desktop, Android, and iOS public
      client IDs, authorization-code flow with PKCE, scopes, redirect URIs,
      claims, role mapping, WebFinger discovery, and CSP.
- [ ] Enforce MFA in Keycloak for every routine and administrative identity.
      Test TOTP or WebAuthn/passkey enrollment, recovery codes, session
      revocation, and a lost-device procedure before file migration.
- [ ] Disable OpenCloud's built-in IDP for routine authentication. Do not place
      Cloudflare Access in front of Keycloak; OpenCloud clients must reach the
      native OIDC authorization endpoints directly.
- [ ] Restrict Keycloak's administrative surface to Tailscale where supported
      without breaking its public issuer/discovery endpoints. Otherwise retain
      a separate MFA-protected administrator, disable default/bootstrap
      credentials, and verify administrative endpoints cannot be used
      anonymously.
- [ ] Confirm `ss -lntp` shows the Keycloak application listener only on
      `127.0.0.1:8080`, and that the management listener is neither tunneled nor
      firewall-exposed.
- [ ] Validate the generated tunnel rules with `cloudflared tunnel ingress
      validate` and exercise an OIDC login before creating real users.
- [ ] Create separate routine OpenCloud and administrative identities. Use one
      revocable, expiring app token per WebDAV or third-party client; app tokens
      provide full account data access, so do not reuse them between devices.

The authentication design follows OpenCloud's
[internal/external IDP guidance](https://docs.opencloud.eu/docs/next/admin/configuration/authentication-and-user-management/)
and [app-token behavior](https://docs.opencloud.eu/docs/user/admin/app-tokens/).

#### Cloudflare limits and later nginx migration

Cloudflare proxies and terminates the public HTTPS connection. The Free and Pro
plans currently limit an individual proxied request body to 100 MB. OpenCloud
clients may chunk some uploads, but the following must be proven independently:

- [ ] Upload 50 MB, 150 MB, and one representative largest file through the
      browser, Android client, desktop client, and WebDAV.
- [ ] Test interrupted/resumed uploads, large downloads, range requests,
      WebSockets, OIDC redirects, shares, and WebDAV methods.
- [ ] Confirm responses for private files are not cached and secrets never
      appear in Cloudflare-visible URLs or logs.

If required clients cannot reliably upload large files, migrate later without
changing client-visible URLs:

1. Deploy nginx on HP with ACME TLS for the same `cloud.<domain>` and
   `auth.<domain>` hostnames.
2. Obtain a public IP or IPv6 path, configure dynamic DNS if necessary, and
   forward only TCP `443` to nginx.
3. Test nginx through an alternate hostname before changing production DNS.
4. Change the Cloudflare records to DNS-only/direct ingress and disable the
   Tunnel routes after convergence.

That direct-nginx migration is explicitly deferred; do not run both ingress
paths indefinitely or expose OpenCloud's backend port directly. Cloudflare's
current upload limits are documented here:
[Cloudflare HTTP 413 limits](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/4xx-client-error/error-413/).

#### Declarative web apps

Start with no optional web apps. The NixOS module declaratively supplies core
web and IDP assets, but it does not currently expose an `extraApps` option.
Do not run an activation script that downloads latest releases into mutable
state or deletes the app directory on every rebuild.

If an optional app is later justified, pin an app release and hash, verify its
compatibility with the pinned OpenCloud version, and expose an immutable app
directory through `WEB_ASSET_APPS_PATH`. The following is a pattern, not a
ready-to-build app declaration; replace both placeholders:

```nix
let
  exampleOpenCloudApp = pkgs.fetchzip {
    url = "<pinned-release-asset-url>";
    hash = "<sha256-SRI>";
    stripRoot = false;
  };
  opencloudWebApps = pkgs.linkFarm "opencloud-web-apps" [
    { name = "example"; path = exampleOpenCloudApp; }
  ];
in {
  services.opencloud.environment.WEB_ASSET_APPS_PATH =
    "${opencloudWebApps}";
}
```

This follows the direction discussed in the
[NixOS OpenCloud web-app thread](https://discourse.nixos.org/t/how-to-install-opencloud-web-apps/77137/3)
without treating its mutable activation-script experiment as a reviewed module.
Apps that require mutable configuration or secrets need a separate design;
never place secrets in a derivation or app asset directory.

#### Clients and data boundary

- [ ] Install and test the OpenCloud Android and desktop clients plus browser
      upload/download and a WebDAV client using an app token.
- [ ] Configure the workstation with fully materialized local synchronization
      for folders that require a complete offline copy. Do not count virtual or
      offline-on-demand placeholders as a second copy or backup source.
- [ ] Configure Lenovo selectively according to storage and travel needs.
- [ ] Define only `Documents`, `Pictures`, `Music`, and `Shared` in OpenCloud.
      Confirm that `Vault`, active code repositories, and Hermes state are absent.
- [ ] Verify no OpenCloud client root contains the Syncthing-managed vault and
      no Syncthing folder contains an OpenCloud-managed directory.
- [ ] Keep irreplaceable data outside OpenCloud until the HP Restic job and an
      isolated OpenCloud recovery test in this phase have succeeded.

Acceptance:

- The native NixOS service starts only when `/srv/opencloud` is mounted and
  listens on loopback; it has no LAN or WAN listener, and the Cloudflare Tunnel
  connector is its only configured public ingress.
- With the T7 disconnected, `/srv/opencloud` is not considered a valid data
  mount, OpenCloud does not start, Restic reports the OpenCloud source as
  unavailable, and no service writes into a fallback directory on HP's root
  filesystem. Reconnecting the T7 and restoring the UUID-backed mount allows
  the service to recover normally.
- The mounted T7 passes the filesystem xattr round-trip test, and the recovery
  runbook records its serial, filesystem UUID, USB connection details,
  replacement procedure, capacity budget, and any encryption-key procedure.
- OpenCloud server, web, and IDP-web assets evaluate from the
  `pkgs-unstable.opencloud` package family and their versions are recorded.
- A clean browser and Android client on a non-tailnet cellular connection reach
  `cloud.<domain>`, authenticate through Keycloak, and complete MFA.
- A Linux file browser and Android client can create, modify, rename, download,
  and delete a disposable file through the service.
- Client devices hold no server filesystem or S3 backup credential.
- Direct HTTP and unauthenticated WebDAV access fail.
- Cloudflare caching is bypassed, Cloudflare Access is absent, and the reviewed
  large-upload/client matrix passes or blocks migration pending direct nginx.
- HP accepts no unsolicited internet connection on the OpenCloud, Keycloak,
  HTTP, or HTTPS backend ports; disabling the tunnel removes public reachability
  while local/Tailscale recovery access remains.
- A file uploaded from Android exists on HP storage and is included in the next
  verified Restic snapshot without depending on the workstation being online.
- The Obsidian vault continues to synchronize only through Syncthing and is
  neither visible nor modified through OpenCloud.
- Removing a single client app token revokes that client without changing the
  account password or another client's token.

### 5.2 Mirror GitHub repositories on HP

Files:

- add `modules/features/backup/github-mirror.nix`
- add a version-controlled repository-owner allowlist
- add the GitHub mirror preparation and validation script
- HP backup SOPS profile
- `hosts/hp-server/configuration.nix`

Configure a dedicated unprivileged `github-mirror` service account on HP that
maintains a working mirror set under `/var/lib/github-mirrors/work` and publishes
the last completely validated set at `/var/lib/github-mirrors/current`. Root may
read these paths for Restic, but ordinary users and unrelated services may not.
The service is a backup source preparer: it completes and validates all
repository updates before publishing the directory Restic reads.

Actions:

- [ ] Create a dedicated GitHub credential with read-only access to repository
      metadata and contents, including private repositories that must be backed
      up. Store it only in the HP SOPS profile and expose it only to the mirror
      service as `GH_TOKEN` or an equivalent credential file.
- [ ] Declare the personal GitHub owner and every organization owner that is in
      scope. Do not assume listing the personal owner traverses organization
      ownership boundaries.
- [ ] Discover repositories with `gh repo list <owner> --limit <reviewed-limit>
      --json nameWithOwner,url,isArchived,isFork` or an equivalent paginated
      GitHub API query. Set an explicit limit and fail if the result reaches that
      limit so silent truncation cannot produce a falsely complete inventory.
- [ ] Use HTTPS remotes with GitHub CLI's credential helper (or an equivalent
      non-interactive helper reading the SOPS-provided token). Never embed the
      token in a repository URL, Git configuration, manifest, or command line.
- [ ] Create new repositories with `git clone --mirror`. Maintain existing
      mirrors with `git remote update --prune`; do not create or edit working
      trees in the mirror directory.
- [ ] Run `git lfs fetch --all` for repositories using Git LFS so the mirror is
      not limited to LFS pointer files.
- [ ] Validate every updated mirror with `git fsck --full` and record its remote
      URL, fetched default branch/HEAD, update time, and validation result in a
      root-owned manifest without credentials.
- [ ] Validate Git LFS separately from ordinary Git objects. `git fsck` does not
      validate LFS payloads. Run `git lfs fsck --objects --pointers` against a
      reviewed revision set covering every mirrored ref, enumerate every LFS OID
      reachable from all refs with `git lfs ls-files --all --long`, and verify
      that each corresponding local LFS object exists and matches its SHA-256.
      Fail validation if an LFS fetch exclusion omits a required object.
- [ ] Treat an inaccessible, transferred, renamed, or missing repository as a
      degraded source condition. Preserve the existing local mirror and never
      delete it automatically merely because it is absent from a later GitHub
      inventory response.
- [ ] Do not run destructive object expiry such as `git gc --prune=now` in the
      mirror service. Force-pushed or deleted refs disappear from the current
      mirror after an update, but prior Restic snapshots must retain earlier
      repository states.
- [ ] Complete repository discovery, all fetches, LFS downloads, validation, and
      the manifest atomically with respect to the backup service. Restic must not
      run against mirrors that are still being updated.
- [ ] Never mutate the published `current` set in place. Refresh a separate
      working set, validate it completely, then publish it through an atomic
      directory swap or tested read-only filesystem snapshot. On any refresh or
      validation failure, discard the partial working result and retain the
      previous `current` set. Include the required snapshot/reflink/full-copy
      headroom in the Phase 0 capacity decision.
- [ ] Serialize refresh publication and Restic traversal with one shared lock.
      Keep the previously published tree available until Restic releases that
      lock; an atomic rename followed by immediate recursive deletion of the old
      tree is not a safe backup boundary.
- [ ] Document that repository mirrors contain Git data only. GitHub issues,
      pull-request discussion, releases/assets, Actions artifacts, packages,
      repository settings, and other GitHub-hosted metadata are outside this
      phase unless separately exported and tested later.

Acceptance:

- Every in-scope personal and organization repository appears in the manifest.
- Private repositories can be mirrored without exposing the GitHub credential
  in the Nix store, process arguments, logs, or repository remotes.
- A new repository is discovered automatically on the next successful run.
- A missing or inaccessible repository is retained locally and marks the source
  status degraded instead of being deleted.
- Every mirror and every Git LFS object reachable from its mirrored refs
  validates before that mirror set is marked current.
- No service on HP can push through the mirror credential.

### 5.3 Provision the Restic backup bucket and identity

Provider-side actions:

- [ ] Create the distinct `restic-backup` bucket and Restic prefix.
- [ ] Block all public access.
- [ ] Enable bucket versioning.
- [ ] Enable provider-side encryption in addition to Restic encryption.
- [ ] Create a dedicated HP backup identity scoped to the Restic
      bucket/prefix.
- [ ] Allow only the object/list operations Restic requires. Record that normal
      Restic operation requires `DeleteObject` for transient locks; do not call
      the HP identity IAM-write-only or technically immutable merely because
      retention commands are disabled.
- [ ] Deny bucket-policy, ACL, public-access, and account-management changes.
- [ ] Deny permanent deletion of noncurrent object versions.
- [ ] Keep the administrative identity off all three machines and protect it
      with MFA and offline recovery codes.
- [ ] Configure a provider billing/budget alert. Note that bucket versioning
      plus twice-daily snapshots with no lifecycle rules (deliberately deferred,
      see below) means stored size and cost grow monotonically until
      retention/lifecycle work is done — set the alert threshold with that in
      mind rather than being surprised by it later.

Do not configure lifecycle expiration, archival transitions, Object Lock, or
automated permanent deletion in this phase.

Acceptance:

- Public and anonymous access fail.
- The HP backup identity can initialize and use only the intended prefix.
- The HP backup identity cannot change bucket policy or permanently delete a
  noncurrent version.
- A normal backup can create and remove its transient lock without granting the
  HP identity `DeleteObjectVersion` or bucket-administration permissions.

### 5.4 Implement the HP Restic module and consistent source backup

Files:

- add `modules/features/backup/restic-s3.nix`
- add version-controlled include/exclude files
- add `modules/features/backup/opencloud-consistent-source.nix`
- add an OpenCloud backup preparation/finalization script
- add a consistent Keycloak database/realm and selected user-directory export
  script
- add a Hermes export preparation script (see below)
- consume the completed GitHub mirror manifest from 5.2
- `hosts/hp-server/configuration.nix`
- HP backup SOPS profile

Prefer NixOS's built-in `services.restic.backups` module. Add a thin wrapper
only for behavior that cannot be expressed by the built-in module.

Configure:

- root-run backup service
- S3 environment file and repository password file from SOPS
- twice-daily persistent timer with at most one hour of randomized delay; this
  leaves room for one failed run and a retry while preserving the 36-hour RPO
- no `pruneOpts`, `forget`, or repository-deletion automation
- every backup source passed as an explicit path; do not rely on traversal from
  `/` or `/var/lib` to cross the dedicated OpenCloud mount
- structured journal output without secret values
- `/var/lib/restic-status/last-success` and
  `/var/lib/restic-status/last-source-status` timestamp/status files for later
  monitoring integration
- an explicit dependency on the HP data mount
- an explicit ordering on the GitHub mirror preparation service from 5.2, but
  not a hard `Requires=` gate on a successful refresh: a failed refresh preserves
  and backs up the last validated mirror set, marks that source degraded, and
  must not prevent a current OpenCloud or vault backup
- sufficient free-space and mount-source checks before backup
- a consistent OpenCloud backup boundary using exactly one of the two modes
  below; a live Restic read of OpenCloud state is not allowed
- a consistent identity-stack boundary: create a native logical backup of the
  Keycloak database, export reviewed realm configuration where supported, and
  use the selected LDAP/directory service's documented consistent export. Do
  not copy a live PostgreSQL or directory database tree.
- failure-safe cleanup implemented as an idempotent systemd `ExecStopPost`, so
  an interrupted or failed preparation starts OpenCloud when safe and releases
  temporary snapshot mounts
- a consistent Hermes export boundary using the same pattern as OpenCloud: if
  Hermes is a live service with its own on-disk state, do not snapshot that
  state directly. Use a Hermes-native export/checkpoint command, or a
  lock-file-gated copy that waits for Hermes to reach a quiescent point,
  before Restic runs — the same "dump before backup, never snapshot live
  state" rule applied to the database applies here.
- a consistent staged source for the Syncthing vault. Query Syncthing's REST API
  (`/rest/db/status` for the vault folder) and require `"state": "idle"`,
  `"needTotalItems": 0`, and `"pullErrors": 0`; then stop Syncthing before
  creating a filesystem snapshot or preserved-attribute copy. An idle response
  is only a point-in-time status and is not itself a lock. Start Syncthing again
  immediately after the staged source is published. HP is an always-on peer,
  not an interactive vault editor, so no other local process may write the vault
  during this short staging window.
- failure-tolerant auxiliary source staging. Identity, vault, Hermes, and GitHub
  refreshes publish a new `latest` directory or manifest only after validation.
  A failed refresh leaves the previous validated source intact, records that
  source as degraded, and does not abort backup of current OpenCloud data or the
  other valid sources. Failure to create the current consistent OpenCloud source,
  loss of the HP data mount, or missing repository credentials remains a hard
  failure that aborts the combined backup.

Initial backup paths:

- the complete, consistent OpenCloud state source from the dedicated HP
  filesystem, including configuration, system data, metadata, blobs, search
  index, identity data, service keys, and any non-declarative app state
- a stopped-service copy of `/etc/opencloud`, including the generated
  `opencloud.yaml`, plus a manifest recording the package version, flake lock
  revision, source paths, snapshot mode, mount identity, and xattr probe result
- `/var/lib/opencloud-identity-backup/latest`, containing the latest validated
  Keycloak database/realm and user-directory exports plus a versioned manifest;
  SOPS remains authoritative for declarative secrets and is not replaced by
  this export
- `/var/lib/vault-backup/latest`, an atomically published snapshot or
  preserved-attribute copy of the current HP Syncthing vault. The current source
  path is `/home/henhal/Vault`, derived from the configured Syncthing user home;
  record and assert that evaluated path instead of inventing `/srv/syncthing`
- the latest validated consistent Hermes export folder; a failed refresh retains
  the previous export and records it as degraded
- `/var/lib/github-mirrors/current` and its validated repository manifest; a
  failed refresh retains the previously published set and records it as degraded
- reviewed HP service configuration/state that is not reproducible from Git,
  NixOS configuration, SOPS, or documented installation procedures

Initial excludes:

- unrelated OS downloads and desktop trash outside the OpenCloud state tree
- `node_modules`, build outputs, and dependency caches
- VM/container images and Docker data
- browser caches and transient profiles
- Docker image/layer data; back up only reviewed persistent application state

Do not initially exclude an internal OpenCloud directory merely because its
name suggests cache, search, preview, or temporary data. The official backup
guide identifies configuration, system data, metadata, and blobs as mandatory
and only says the search index may be rebuilt. Start with the complete stopped
state tree; optimize exclusions only after an isolated restore proves the
matching rebuild procedure.

#### Syncthing vault consistency boundary

Do not run Restic directly against the live HP vault and do not treat one idle
API response as a lock:

1. Assert that the configured HP folder ID is `vault` and resolve its actual
   path from the evaluated Syncthing configuration. Initially this is
   `/home/henhal/Vault`.
2. Request a Syncthing scan, then poll `/rest/db/status?folder=vault` until the
   folder is `idle`, `needTotalItems` is zero, `pullErrors` is zero, and those
   values remain stable across two checks.
3. Stop `syncthing.service` and confirm it is inactive. No interactive user or
   other HP-local process may edit the vault during the staging window.
4. Create either a read-only filesystem snapshot or a temporary
   preserved-attribute copy using a tool and flags that retain ownership, modes,
   timestamps, symlinks, ACLs, and xattrs. Validate the temporary source before
   atomically replacing `/var/lib/vault-backup/latest`.
5. Start Syncthing immediately after publication. Implement restart and temporary
   cleanup through idempotent systemd post-stop handling so interruption cannot
   leave synchronization disabled.
6. If scanning, stopping, copying, validation, or publication fails, retain the
   previous `latest` source and record the vault source as degraded. Never publish
   a partial copy.

The staging filesystem and free-space threshold must be included in the Phase 0
capacity decision. A copy on the same HP disk is only a consistency source for
Restic, not an additional backup copy.

#### OpenCloud consistency modes

**Mode A — filesystem snapshot (preferred):** Use this only if the already
provisioned HP data filesystem supports a tested atomic read-only snapshot
(for example, a Btrfs subvolume, ZFS dataset, or LVM snapshot).

1. Verify `/srv/opencloud` is the expected mount and has required free space.
2. Stop `opencloud.service` and wait until it is inactive.
3. Copy `/etc/opencloud` to a root-only staging directory with ownership,
   permissions, ACLs, and xattrs preserved.
4. Create a read-only snapshot of the entire OpenCloud state dataset.
5. Bind-mount the snapshot and staged configuration read-only beneath a stable
   path such as `/run/opencloud-backup/current/`.
6. Start OpenCloud immediately; Restic reads only the immutable snapshot.
7. After Restic exits, unmount and remove the transient local snapshot. This is
   operational cleanup, not Restic retention or S3 deletion.

**Mode B — offline backup window:** Use this on ext4 or any layout without a
tested snapshot facility. Stop OpenCloud before Restic starts and keep it
stopped until Restic finishes reading the entire state/config recovery unit.
This has longer downtime but remains consistent. Do not substitute a hot
`rsync`, live Restic read, or sequential copy while OpenCloud is writing.

Do not add a new filesystem, convert an existing filesystem, or create a new
volume implicitly in this phase. If Mode A requires such work, keep Mode B and
move the storage change to the high-risk storage plan.

The wrapper should expose one stable source tree to Restic in both modes:

```text
/run/opencloud-backup/current/
  state/           read-only snapshot or offline bind mount of OpenCloud state
  config/          stopped-service copy of /etc/opencloud
  manifest.json    version, paths, mount ID, timestamps, xattr/snapshot checks
```

Illustrative Restic module wiring:

```nix
services.restic.backups.hp-offsite = {
  user = "root";
  repository = "s3:<provider-endpoint>/<bucket>/<prefix>";
  environmentFile = config.sops.templates."restic-s3-env".path;
  passwordFile = config.sops.secrets.RESTIC_REPOSITORY_PASSWORD.path;
  initialize = false; # initialize manually once, then remove ambiguity.
  paths = [
    "/run/opencloud-backup/current"
    "/var/lib/opencloud-identity-backup/latest"
    "/var/lib/vault-backup/latest"
    "/var/lib/github-mirrors/current"
    "/var/lib/hermes-backup/latest"
  ];
  timerConfig = {
    OnCalendar = "*-*-* 03,15:00:00";
    Persistent = true;
    RandomizedDelaySec = "1h";
  };
  pruneOpts = [ ];
  backupPrepareCommand = ''
    exec ${opencloudBackupSource}/bin/opencloud-backup-source prepare
  '';
  backupCleanupCommand = ''
    ${opencloudBackupSource}/bin/opencloud-backup-source cleanup
  '';
};

systemd.services.restic-backups-hp-offsite = {
  requiresMountsFor = [ "/srv/opencloud" ];
  after = [
    "github-mirror.service"
    "opencloud-identity-export.service"
    "syncthing-vault-backup.service"
    "hermes-export.service"
  ];
  wants = [
    "github-mirror.service"
    "opencloud-identity-export.service"
    "syncthing-vault-backup.service"
    "hermes-export.service"
  ];
};
```

The auxiliary refresh services must be rerunnable on every backup invocation;
do not leave a successful oneshot permanently active with `RemainAfterExit` in
a way that prevents the next scheduled refresh. `Wants=` plus `After=` waits for
each attempt but does not fail the Restic unit merely because a refresh failed.

The actual preparation command must assert mounts/free space and produce the
current OpenCloud source before it publishes
`/run/opencloud-backup/current`. Auxiliary refresh scripts produce and validate
the identity-stack export, staged Syncthing vault, Hermes export, and GitHub
manifest independently. They must use temporary paths plus atomic rename, never
replace a valid `latest` source with a partial result, and record failure without
returning a fatal status to the OpenCloud backup coordinator. Publication and
Restic traversal must share a lock so a manual refresh cannot replace or remove
a published tree while Restic is reading it. The combined snapshot includes the
last validated auxiliary sources and records their age and degraded status in
its manifest. Its cleanup command must be safe to run
repeatedly and after partial preparation. Do not depend only on a shell `trap`
inside `backupPrepareCommand`, because that process exits before Restic runs;
systemd-level post-stop cleanup is the durable boundary.

Restic backs up and restores extended attributes by default on Linux. Do not
use `--exclude-xattr`, and prove the behavior with a restored OpenCloud file
whose metadata-bearing xattrs are compared before the isolated service starts.

Acceptance:

- The repository initializes without placing credentials in the Nix store.
- Two consecutive scheduled snapshots succeed, including one after a deliberately
  failed auxiliary-source refresh.
- The second snapshot deduplicates unchanged data.
- The OpenCloud state and stopped-service configuration sources are verified
  directly (e.g. `restic ls` against the latest snapshot), not assumed from a
  successful exit code alone.
- The validated GitHub mirror manifest and representative bare repositories are
  present in the snapshot.
- The current Keycloak/user-directory export and its manifest are present and
  pass their native validation checks.
- No automated retention command deletes snapshots, pack data, or index data.
  Normal creation and deletion of transient Restic lock objects remains allowed
  and must not be confused with retention or repository-data deletion.
- A failed or interrupted OpenCloud preparation or Restic backup returns
  OpenCloud to service and records failure without updating the backup-success
  timestamp.
- A failed or interrupted auxiliary refresh leaves its previous validated
  source intact, records that source as degraded, and does not prevent Restic
  from protecting current valid sources. A successful degraded snapshot updates
  backup-success time but never reports the complete source set healthy.
- A failed or interrupted Hermes export leaves Hermes running normally and its
  previous validated export intact.
- The service is never observed running while Mode B reads live state, or while
  Mode A creates its snapshot.
- A restored test file retains its OpenCloud xattrs, ownership, mode, and ACLs.

### 5.5 Track backup success separately from source freshness

Files:

- backup pre/post scripts in the Restic module
- OpenCloud snapshot/config manifest and status file
- Keycloak/user-directory export manifest and status file
- staged Syncthing vault manifest and status file
- Hermes export script/status file
- GitHub mirror preparation script/manifest/status file

Actions:

- [ ] Record successful creation and age of the OpenCloud consistent source,
      config copy, and recovery manifest.
- [ ] Record the HP data mount identity, available space, OpenCloud state
      readability, selected consistency mode, package version, and xattr test
      before each backup.
- [ ] Record the age and validation result of the Keycloak database/realm and
      selected user-directory exports. A missing or stale identity export makes
      the source set degraded even if OpenCloud file data is current.
- [ ] Record the HP Syncthing vault path, readability, and synchronization
      status plus the staged-source manifest from 5.4; do not report the source
      set healthy while the vault has pending items, pull errors, an unhealthy
      folder state, or a failed/partial staging attempt.
- [ ] Record the age and validation result of the GitHub inventory, every
      repository mirror, and required LFS fetches. A truncated inventory,
      inaccessible repository, failed fetch, or failed `git fsck` degrades the
      source set without preventing a snapshot of other current sources. Include
      the separate all-ref LFS validation result from 5.2.
- [ ] Record the age of the latest consistent Hermes export and whether the
      export boundary script completed successfully.
- [ ] Mark source status as degraded when the OpenCloud consistent source,
      recovery manifest, identity-stack export, Hermes export, or last fully
      validated GitHub mirror set exceeds 36 hours, or when the data filesystem
      approaches its reviewed free-space threshold.
- [ ] Update backup-success status only after Restic completes successfully,
      even when an auxiliary source is explicitly recorded as degraded. Track
      backup completion and source freshness as separate fields; only their
      combination may be reported as an overall healthy recovery set.
- [ ] Do not equate `Restic exited successfully` with `all required recovery
      inputs were current`.

Until monitoring is implemented, document a weekly manual check of the systemd
timer, latest snapshot, and the two status files.

Acceptance:

- A stale OpenCloud source, missing data mount, failed snapshot/config copy, or
  failed xattr check prevents a falsely healthy OpenCloud backup result.
- A stale or invalid Keycloak/user-directory export prevents a falsely healthy
  identity and overall source-set result.
- An unreadable or unhealthy HP vault copy prevents a falsely healthy overall
  source-set result.
- A stale or failed Hermes export prevents a falsely healthy overall
  source-set result without preventing current valid sources from being backed
  up.
- A stale, incomplete, inaccessible, or invalid GitHub mirror set prevents a
  falsely healthy overall source-set result without deleting prior mirrors or
  blocking current valid sources from being backed up.
- A Restic failure does not update the success timestamp.
- After one deliberately failed scheduled attempt, the next scheduled attempt
  succeeds before the previous successful snapshot becomes 36 hours old.
- Secret values never appear in status files or journal output.

### 5.6 Verify recovery

- [ ] Restore one file to a temporary directory.
- [ ] Restore one complete folder to a separate location.
- [ ] Restore representative Obsidian notes and an attachment from the HP
      Syncthing vault snapshot without writing into the live vault.
- [ ] Restore one complete bare Git mirror and its LFS objects to a temporary
      directory, clone a working tree from the restored mirror without GitHub
      access, and verify representative branches, tags, history, and files.
- [ ] Restore a repository state from before a force-push or deleted branch in
      an older Restic snapshot and verify the removed commit remains reachable.
- [ ] Restore using a clean Restic cache.
- [ ] Verify file contents and permissions.
- [ ] Restore the complete OpenCloud state, `/etc/opencloud` copy, manifest,
      generated keys, and optional app assets to an isolated filesystem that
      supports xattrs.
- [ ] Restore with the exact OpenCloud package/flake revision recorded in the
      manifest before attempting an upgrade.
- [ ] Compare representative xattrs, ownership, modes, and ACLs before starting
      the isolated service.
- [ ] Run `opencloud backup consistency --fail -p <actual-storage-users-path>`
      against the restored storage. Derive the path from the restored version's
      evaluated configuration; do not copy a Docker Compose default path from
      newer documentation.
- [ ] Start the isolated instance on loopback and an unused port with no
      Cloudflare Tunnel route, public DNS route, or other public proxy.
- [ ] Restore Keycloak, its database/realm configuration, and the selected
      user-directory export in isolation before connecting OpenCloud. Verify the
      issuer, required claims/roles, MFA enrollment/recovery, and a routine user
      login without exposing the restored identity service publicly.
- [ ] Verify login plus listing, download, rename, upload, and deletion of
      disposable files in the isolated instance.
- [ ] Verify recovery using only the repository URL, restricted credentials,
      Restic password, this repository, and a fresh NixOS environment.
- [ ] Store verified offline copies of the Restic password, SOPS personal age
      key, S3/Cloudflare/domain-registrar recovery codes, Keycloak break-glass
      material, and recovery instructions.
- [ ] Record the measured single-file and folder restore times.

No retention, pruning, lifecycle deletion, or Object Lock work begins here.
Those remain in the high-risk runbook.

Acceptance:

- The initial backup is not considered complete until the required OpenCloud,
  Keycloak/user-directory, ordinary-file/folder, vault, and Git mirror restore
  tests pass.
- Recovery does not depend on the original HP server's Restic cache or
  decrypted local secret files.

## Phase 6: Migrate OpenCloud Files and Narrow Syncthing to the Vault

File:

- `modules/features/network/syncthing.nix`

### 6.1 Prepare and migrate the authoritative dataset

- [ ] Confirm the isolated OpenCloud restore passed before migration.
- [ ] Resolve existing Syncthing conflicts before changing topology.
- [ ] Inventory pre-existing same-name folders on Lenovo and HP.
- [ ] Move conflicting target content to dated quarantine directories rather
      than deleting or merging it automatically.
- [ ] Confirm HP destination capacity, workstation client capacity, and the
      expected Lenovo selective-sync set.
- [ ] Add explicit ignore patterns for caches, temporary data, and unsafe live
      databases.
- [ ] Confirm the vault has a healthy HP Syncthing copy and keep it outside the
      OpenCloud migration set.
- [ ] Pause Syncthing for each OpenCloud-bound folder immediately before its
      migration window so there is one writer and a stable source.

### 6.2 Migrate one folder at a time

Order:

1. `Documents`
2. `Pictures`
3. `Music`
4. `Shared`

For each folder:

- [ ] Upload from the reconciled workstation source through the OpenCloud
      client or supported WebDAV/API path; never copy directly into the server data
      directory.
- [ ] Wait for server-side completion and verify counts, representative hashes,
      names, timestamps, and browser access.
- [ ] Let the workstation OpenCloud client converge to a complete local
      copy where required; configure Lenovo selectively when it is online.
- [ ] Test create, edit, rename, conflict, and delete behavior with disposable
      files.
- [ ] Run and verify an HP Restic snapshot containing the migrated folder.
- [ ] Retire that folder from Syncthing on all peers only after the OpenCloud
      clients and off-site snapshot are verified. Preserve quarantined source data
      through the rollback window.
- [ ] Wait for completion before starting the next folder.

Do not run Syncthing and OpenCloud over the same live folder. OpenCloud trash
and versions are convenience features, not substitutes for Restic.

After those migrations, retain only the Obsidian `Vault` as the routine
personal Syncthing folder. Keep its HP peer enabled so the Restic source does
not depend on the workstation or an Android device being online. Any additional
Syncthing service export requires a separate reviewed path and purpose.

Acceptance:

- OpenCloud and intended offline client copies converge for each durable folder.
- The migrated OpenCloud folders are no longer shared by Syncthing, while the
  vault remains healthy on its explicitly paired devices and HP.
- A disposable deletion propagates as expected and the pre-change Restic
  snapshot can restore the deleted file.
- Existing target data was quarantined or reconciled, never silently removed.

### 6.3 Add the Hermes export

Files:

- HP Hermes runtime/export support
- HP backup source list

Actions:

- [ ] Identify which Hermes state is irreplaceable.
- [ ] Use an upstream-supported export or stop/quiesce mechanism to create a
      consistent export.
- [ ] Write exports atomically into a dedicated local HP backup source
      directory.
- [ ] Keep live databases and mutable runtime state out of both OpenCloud and
      Syncthing.
- [ ] Retain at least the latest successful export locally; remote history is
      supplied by Restic snapshots.
- [ ] Verify a test import into a disposable Hermes state directory.

Acceptance:

- The export can restore essential configuration/memory without copying a live
  database mid-write.
- The HP Restic snapshot contains the export.

## Phase 7: Documentation and Incident Procedures

Update:

- `README.md`
- `docs/HOSTS.md`
- `docs/FEATURES.md`
- `docs/SECRETS.md`
- add a backup recovery runbook
- add an incident-response runbook

Document:

- actual per-host feature imports after deduplication
- driverless printer setup and the one retained vendor fallback, if any
- Docker hosts and the security significance of Docker-group membership
- OpenCloud architecture, unstable package family, custom domains, Cloudflare
  Tunnel/DNS/cache boundary, Keycloak OIDC/MFA, app-token revocation,
  break-glass recovery, later nginx migration, bucket-credential isolation,
  and OpenCloud/identity-stack recovery material
- manual Hermes installation, update, repair, and service-user procedure
- pinned Firecrawl revision update and rollback
- Syncthing folder topology and authoritative-source rollout
- GitHub owner inventory, read-only mirror credential, mirror validation,
  Git/LFS recovery, and the commit-and-push requirement for working trees
- Restic backup/restore commands and offline recovery material
- weekly manual backup-status check while monitoring is deferred

Incident procedures must cover:

- lost/stolen Lenovo
- compromised HP or Hermes agent
- compromised workstation
- compromised Cloudflare account, tunnel credential, custom domain, or
  Keycloak administrator
- leaked S3, Cloudflare Tunnel, Keycloak/OIDC, GitHub mirror, or AI-provider
  credentials
- unwanted Syncthing deletion or corruption

Each procedure should identify which Tailscale node, SSH key, Syncthing device,
SOPS recipient, service credential, and provider identity must be revoked or
rotated.

## Verification Matrix

### Static validation

- [ ] Git whitespace checks pass.
- [ ] Flake evaluation succeeds.
- [ ] All three host system closures build.
- [ ] No secret value is present in evaluated derivations or generated unit
      definitions.
- [ ] Only intended flake inputs changed.

### Workstation

- [ ] Local login, sudo, SSH, Tailscale, OpenCloud client, Docker, printing, scanning,
      removable media, Vial, and monitor brightness work.
- [ ] Interactive AI credentials load automatically.
- [ ] Intended complete OpenCloud folders are locally available and virtual
      placeholders are not misreported as complete copies.

### Lenovo

- [ ] Local login, sudo, SSH, Tailscale, selective OpenCloud sync, printing, scanning,
      removable media, KDE Connect, Bluetooth, and ADB work.
- [ ] Docker is absent unless explicitly retained.
- [ ] HP-only and backup secrets cannot be decrypted.

### HP

- [ ] Local/break-glass access, SSH, Tailscale, Docker, Hermes, and
      Firecrawl work.
- [ ] HP boots without the removed desktop stack.
- [ ] Hermes runs under the intended security boundary.
- [ ] Firecrawl listens only on loopback and uses the pinned external checkout.
- [ ] Printing, Bluetooth, GUI applications, and unrelated desktop services are
      absent unless explicitly retained.
- [ ] The Restic timer, consistent OpenCloud source, status files, and restore
      tests pass; only root can read backup credentials.
- [ ] The Cloudflare Tunnel uses only its scoped credentials, exposes only the
      two reviewed hostnames, and HP has no public backend listener or inbound
      router dependency.
- [ ] The current Keycloak/user-directory export is present in Restic and its
      isolated restore/MFA test passes.
- [ ] The GitHub mirror service discovers every allowlisted owner repository,
      validates Git and LFS data, cannot push, retains missing mirrors, and is
      included in the verified Restic snapshot.

### Remote files

- [ ] Browser, Linux desktop client/WebDAV, and Android client on a non-tailnet
      connection pass public-domain access, Keycloak OIDC/MFA, app-token
      revocation, large-upload, and normal file-operation tests.
- [ ] No client or OpenCloud service account holds an S3 backup credential;
      unauthenticated access fails.
- [ ] No OpenCloud, Keycloak, Hermes, or interactive account can read the
      Cloudflare Tunnel credential; no client device needs it.
- [ ] An isolated restore of the complete OpenCloud state, configuration, keys,
      metadata/xattrs, local blobs, and Keycloak/user-directory recovery unit
      completes from the Restic repository.

## Rollback Strategy

- Configuration ownership moves: revert the phase commit and rebuild the
  affected host.
- SSH/Tailscale: use preserved local console/LAN access and boot the previous
  generation if necessary.
- Secret migration: retain old encrypted entries until every new consumer is
  verified; revoke old credentials only afterward.
- Hermes: keep the previous manual installation/state until the dedicated-user
  service passes functional tests.
- Firecrawl: retain the previous upstream revision and Compose override for one
  rollback window.
- OpenCloud: disable the Cloudflare DNS/Tunnel routes; if compromise is
  suspected, revoke the tunnel credential, app tokens, and identity-provider
  sessions;
  preserve the HP data filesystem and recovery material, and return to the
  quarantined pre-migration source until an isolated restore is verified.
- Restic: disable the timer without deleting the repository; never repair,
  prune, or recreate the repository as an automatic response to an error.
- Syncthing: pause the folder, restore quarantined target content, and use the
  verified Restic snapshot if data was removed.
- GitHub mirrors: revoke the read-only credential, disable mirror preparation
  without deleting existing mirrors, restore the last validated mirror set if
  needed, and issue a replacement credential before resuming.

## Proposed Commit Boundaries

Commits are suggestions only and are not authorized by this plan:

1. `refactor(system): move services out of base`
2. `refactor(hosts): scope docker printing and io`
3. `chore(flake): remove unused hermes and vscode inputs`
4. `security(users): remove weak initial password`
5. `security(ssh): audit keys and restore defaults`
6. `security(network): scope tailscale firewall access`
7. `security(secrets): split practical secret profiles`
8. `security(hermes): isolate manual agent runtime`
9. `security(firecrawl): isolate checkout and secrets`
10. `server(hp): remove unrelated desktop surface`
11. `storage(opencloud): add unstable hp file service`
12. `security(identity): add opencloud oidc mfa`
13. `network(cloudflare): publish opencloud tunnel`
14. `backup(git): mirror github repositories on hp`
15. `backup(hp): add encrypted restic s3 snapshots`
16. `backup: add source state and restore checks`
17. `storage(opencloud): migrate durable folders`
18. `backup: add consistent hermes export`
19. `docs: document security sync and recovery`

## Definition of Done

- [ ] No host is created with the password `password`.
- [ ] SSH is key-only and every authorized key has a known owner/device.
- [ ] Tailnet and firewall exposure match the documented access matrix.
- [ ] Interactive AI secrets remain convenient while HP-agent and backup
      credentials remain isolated.
- [ ] Background Hermes does not inherit unrestricted interactive-user or
      Docker access.
- [ ] Firecrawl secrets are root-only and Firecrawl is loopback-only.
- [ ] `base.nix` contains no Docker, printer, desktop I/O, monitor, or
      device-specific behavior.
- [ ] Printing/scanning work on workstation and Lenovo and are absent from HP.
- [ ] HP has verified, consistent encrypted off-site snapshots with S3 versioning
      and restricted IAM.
- [ ] Remote files are usable from browser, Linux, and Android over the reviewed
      Cloudflare Tunnel and Keycloak MFA boundary from non-tailnet devices,
      while the dedicated backup bucket remains unreachable outside Restic
      recovery.
- [ ] Keycloak is the sole interactive OpenCloud identity provider, MFA is
      enforced for routine and administrative accounts, and OpenCloud's
      built-in IDP cannot provide a fallback path around that policy.
- [ ] The Keycloak database, realm configuration, selected user directory, and
      break-glass procedure have passed an isolated restore and login test.
- [ ] Cloudflare caches no private OpenCloud or Keycloak response, Cloudflare
      Access is not inserted into client/OIDC flows, and the large-upload test
      matrix passes.
- [ ] A clean-cache file and folder restore have succeeded.
- [ ] Every in-scope GitHub repository has a validated HP mirror in Restic, and
      a restored mirror can produce a working clone without GitHub access.
- [ ] No automatic retention, pruning, lifecycle expiration, or permanent
      backup deletion is enabled.
- [ ] OpenCloud is authoritative for `Documents`, `Pictures`, `Music`, and
      `Shared`; Syncthing remains exclusive to `Vault` and reviewed service
      exports; no synchronization roots overlap.
- [ ] Live Hermes databases are not synchronized; a tested consistent export
      is remotely backed up.
- [ ] Monitoring services and all high-risk work remain untouched.
- [ ] Documentation matches the implemented host roles and recovery process.
