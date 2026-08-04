# Security, Organization, Sync, and Backup Implementation Plan

Status: Proposed

Created: 2026-07-31
Revised: 2026-08-01

Scope: Low-risk security fixes, configuration organization/deduplication,
self-hosted Nextcloud file access, narrowly scoped machine synchronization,
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
- an MFA-protected Nextcloud service whose files are stored locally on the
  upgraded HP server and are usable from browsers, Linux, and Android
- encrypted off-site Restic snapshots from HP to a dedicated S3 backup bucket
- verified restore procedures
- a hybrid personal-file architecture: Syncthing exclusively for the Obsidian
  vault, Nextcloud for documents/media/shared files, GitHub plus HP-managed Git
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
- Do not migrate irreplaceable files into Nextcloud until the initial off-site
  backup and isolated restore test have succeeded.
- Do not rotate a credential until every intended consumer has switched to the
  replacement.

## Fixed Architecture Decisions

### Machine roles

| Machine             | Role in this plan                                                                                                  |
| ------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `workstation`       | Desktop and development host; initial migration source and complete Nextcloud client mirror where capacity permits |
| `lenovo-yoga-pro-7` | Occasionally connected desktop and selective/offline Nextcloud client                                              |
| `hp-server`         | Always-on Nextcloud storage/application host, Restic uploader, manual Hermes/AI-agent host, and Firecrawl host     |

### Data ownership

- The workstation is authoritative only while the initial Nextcloud dataset is
  prepared and migrated. After verified migration, Nextcloud on HP is
  authoritative for `Documents`, `Pictures`, `Music`, and `Shared`.
- Syncthing remains exclusively responsible for the Obsidian `Vault`. HP is an
  always-on peer and Restic backs up the HP vault copy. The vault must not be
  nested inside or selected by any Nextcloud synchronization root.
- Active code repositories are not synchronized by Nextcloud or Syncthing.
  Developers and agents commit and push through Git; HP discovers and validates
  read-only bare mirrors of the GitHub repositories before Restic snapshots them.
  Only committed and pushed code is covered by this centralized backup path.
- `Downloads`, caches, build artifacts, VM images, browser caches,
  `node_modules`, and live application databases are excluded by default.
- Live Hermes state is not synchronized. HP creates a consistent export in a
  dedicated local backup source directory on HP.
- Nextcloud provides file access and synchronization for its assigned durable
  folders. Syncthing provides peer synchronization only for the vault and any
  separately reviewed service exports. Restic/S3 provides independent backup
  history for both authoritative data sets.

### Storage roles and access boundary

S3 is used only for encrypted off-site backup. Never expose the Restic
repository through a mount, file browser, WebDAV, Nextcloud, or mobile client.

| Role                  | Backend                                        | Consumers                                        | Access model                                       |
| --------------------- | ---------------------------------------------- | ------------------------------------------------ | -------------------------------------------------- |
| General primary files | dedicated local filesystem on HP               | Nextcloud server                                 | service-account-only local access                  |
| General file access   | Nextcloud on HP                                | browser, Linux, Android                          | HTTPS, Nextcloud authentication, and MFA           |
| Obsidian vault        | Syncthing folder with HP as always-on peer     | workstation, Lenovo, Android, HP                 | paired Syncthing devices only                      |
| Active code           | GitHub plus read-only bare mirrors on HP       | developers, agents, HP backup service            | Git push/fetch; never Nextcloud or Syncthing       |
| Off-site backup       | dedicated `restic-backup` S3 bucket and prefix | root-run Restic on HP; recovery environment only | restricted machine credential plus Restic password |

Nextcloud architecture:

- Run a fresh, dedicated Nextcloud instance on HP. Store its data directory on
  the upgraded local storage, not in S3 and not on a FUSE/network mount.
- Give the Nextcloud service exclusive access to its data directory. Users and
  other synchronization tools must access the files through Nextcloud rather
  than editing the server-side data directory directly.
- Publish only the Nextcloud HTTPS endpoint. Use Tailscale-only access first;
  add a hardened public reverse proxy only if access from unmanaged devices or
  public shares is required. Enforce Nextcloud MFA for browser sessions and
  scoped app passwords/tokens for desktop, mobile, and WebDAV clients. Define
  recovery codes and a break-glass administrator procedure before exposure.
- Use the official Nextcloud desktop and Android clients for sync, uploads,
  offline files, sharing, and browser access. Its WebDAV endpoint is available
  to Linux file managers and Android file managers that support WebDAV.
- Treat the Nextcloud data directory, database, configuration, custom apps,
  themes, and encryption keys as one recovery unit. Capture them consistently
  and back them up with Restic to S3.

This is a service, not a shared server-side folder. It adds a database,
cache/Redis, web application, upgrades, monitoring later, and public-endpoint
patching. It is
the smallest design that satisfies browser access, Android usability, sharing,
and MFA without distributing storage credentials to clients.

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
      the dedicated Nextcloud data mount, filesystem, capacity, ownership, health
      checks, and replacement/recovery procedure. Do not perform partitioning or
      filesystem migration implicitly through this plan.
- [ ] Choose an S3-compatible backup provider, region, `restic-backup` bucket
      name, and expected storage/retrieval budget.
- [ ] Confirm the local-storage Nextcloud architecture and which folders need
      complete offline copies on workstation and Lenovo.
- [ ] Choose the public hostname, identity provider, MFA method, recovery-code
      custody, and break-glass procedure for Nextcloud.
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
backup identity, HP storage layout, Nextcloud access boundary,
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

### 3.1 Split secrets into four intentional scopes

Files:

- `modules/features/secrets.nix`
- `.sops.yaml`
- `secrets/shared-interactive.yaml`
- `secrets/hp-agent.yaml`
- `secrets/hp-backup.yaml`
- `secrets/nextcloud.yaml`
- existing host-specific Syncthing secret files

Profiles:

| Profile               | Recipients                                | Owner/mode                                     | Contents                                                        |
| --------------------- | ----------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------- |
| Shared interactive AI | personal keys plus hosts that use AI CLIs | `henhal`, `0400`                               | intentionally interactive provider credentials                  |
| HP agent services     | personal keys plus HP                     | dedicated Hermes user or service owner, `0400` | Hermes, Telegram, Firecrawl and agent-only credentials          |
| Nextcloud service     | personal keys plus HP                     | service account, `0400`                        | database/cache, Nextcloud, mail, and identity-provider secrets  |
| HP backup             | personal keys plus HP                     | `root`, `0400`                                 | Restic repository password and restricted S3 backup credentials |

Actions:

- [ ] Replace wildcard loading of every `/run/secrets` file with one generated,
      allowlisted `interactive-ai.env`.
- [ ] Continue sourcing that file automatically in interactive shells.
- [ ] Generate stable service-specific environment files from SOPS at
      activation time; do not manually decrypt on login or service start.
- [ ] Ensure backup secrets are never exported to an interactive shell.
- [ ] Ensure only root on HP can read backup credentials; the Nextcloud,
      Hermes, Firecrawl, and interactive users cannot read them.
- [ ] Ensure the Nextcloud service account can read only its own service
      secrets and cannot read the Restic/S3 backup credentials.
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
| `Documents` and ordinary PDFs outside the vault          | Nextcloud                                   |
| `Pictures`, phone uploads, `Music`, and `Shared`         | Nextcloud                                   |
| Committed and pushed code repositories                   | GitHub plus HP-managed bare Git mirrors     |
| Live Hermes state                                        | HP-local only; consistent export for Restic |
| Off-site recovery history                                | Restic from HP to S3                        |

Do not configure Nextcloud and Syncthing against the same directory, nested
directories, or alternate paths resolving to the same files. In particular,
keep `Vault` outside `Documents` before enabling the Nextcloud desktop client.
Nextcloud and Syncthing are synchronization systems, not backups.

Local working trees remain ordinary Git clones. Uncommitted changes, untracked
files, ignored files, local-only branches, and commits that have not been pushed
are not covered by the centralized code-backup path. Developers and agents must
commit and push work-in-progress branches before switching machines or ending a
work session. HP mirrors GitHub; it does not synchronize live working trees.

**Obsidian vault stays on Syncthing, not Nextcloud, in all configurations.**
Nextcloud desktop client's virtual-filesystem / online-only / placeholder
modes present files that are not fully materialized on disk; Obsidian and its
plugins expect a real, fully-present folder at all times and will misbehave
or fail against placeholder files. Syncthing keeps a full real copy on every
device by design, which is the only mode compatible with Obsidian. This
constraint applies regardless of which device's Nextcloud client
configuration is used.

- [ ] Add a Syncthing ignore pattern for `.obsidian/workspace.json` and
      `.obsidian/workspace-mobile.json` on any vault synced to more than one
      device. These store per-device window/pane layout; syncing them causes
      UI-state churn and spurious conflict copies unrelated to note content.
- [ ] Expect conflict-copy files (`filename (conflicted copy ...).ext`) as
      normal Syncthing/Nextcloud behavior when the same file is edited on two
      devices before a sync completes. This is expected behavior to review
      periodically, not a fault condition to alarm on.

### 5.1 Provision the MFA-protected Nextcloud service

Files:

- add a dedicated Nextcloud feature module and HP host configuration
- SOPS profile for Nextcloud service secrets
- reverse-proxy and identity-provider configuration

Actions:

- [ ] Verify the upgraded HP RAM and dedicated data filesystem are healthy,
      mounted by stable identifier, large enough for the current dataset plus
      growth and temporary restore space, and not dependent on an interactive
      login.
- [ ] Deploy a fresh Nextcloud instance with PostgreSQL or MariaDB and Redis.
      Place the Nextcloud data directory on the dedicated HP data filesystem.
- [ ] Confirm the data directory's mount is not a separate filesystem that a
      later `--one-file-system` Restic invocation would silently skip (see
      5.4). If it is a separate mount or bind mount, account for it explicitly
      in the Restic path/flag configuration rather than assuming default
      traversal reaches it.
- [ ] Keep the data directory outside `/home`, inaccessible to ordinary users,
      and out of Syncthing. Do not edit it directly or expose it over SMB/NFS.
- [ ] Enable Redis for file locking/transactional file locking and enable
      APCu for local PHP opcache-adjacent caching. Use both together, not
      Redis alone — Nextcloud's own guidance treats this as the standard
      pairing, not an optional extra.
- [ ] Configure Nextcloud's background jobs to run via `cron` triggered by a
      systemd timer (the NixOS `services.nextcloud` module wires this up when
      cron mode is selected), not webcron or AJAX-triggered execution. Verify
      the timer actually fires and background jobs complete; file scanning,
      previews, trash/version cleanup, and encryption housekeeping silently
      degrade if this is misconfigured.
- [ ] Tune PHP-FPM pool sizing (`pm.max_children`) upward from the module
      default if the HP server's RAM allows it, and enable PHP opcache. The
      default pool sizing is conservative and will make initial uploads/scans
      of a large existing dataset noticeably slow otherwise.
- [ ] Configure upload-size, database, background-job, preview, trash/version,
      and resource limits appropriate to the upgraded HP capacity.
- [ ] Publish only HTTPS. Start with Tailscale-only access. If a public endpoint
      is later required, expose it through a hardened reverse proxy without adding
      a browser-only authentication layer that breaks desktop/mobile/WebDAV
      clients. Require Nextcloud MFA and scoped client app passwords/tokens. Do not
      expose SMB, NFS, or a separate administrative interface to the internet.
- [ ] Set `trusted_proxies` and `overwritehost`/`overwriteprotocol` correctly
      for the reverse-proxy path. Missing or wrong values here produce
      intermittent "untrusted domain" errors or redirect loops that look like
      an auth bug but are actually a proxy-header misconfiguration.
- [ ] Create separate least-privilege user and administrator accounts. Keep
      the provider and server administrator identities out of routine file access.
- [ ] Install and test the Nextcloud Android app and desktop client. Test
      browser upload/download and WebDAV access from the existing Linux file
      browser.
- [ ] Configure the workstation client with classic local synchronization for
      folders that require a complete offline copy. Do not count virtual
      placeholders as a second copy or as backup input.
- [ ] Configure Lenovo selectively according to its available storage and
      travel/offline requirements.
- [ ] Define only `Documents`, `Pictures`, `Music`, and `Shared` in Nextcloud.
      Confirm that `Vault`, active code repositories, and Hermes state are absent.
- [ ] Verify that no Nextcloud client root contains the Syncthing-managed vault
      and that no Syncthing folder contains a Nextcloud-managed directory.
- [ ] Keep all irreplaceable data outside Nextcloud until the HP Restic job and
      isolated Nextcloud recovery test in this phase have succeeded.

Acceptance:

- A new browser session and Android client enrollment complete the MFA flow.
- A Linux file browser and Android client can create, modify, rename, download,
  and delete a disposable file through the service.
- Client devices hold no server filesystem or S3 backup credential.
- Direct HTTP and unauthenticated WebDAV access fail.
- Nextcloud's background cron job runs on schedule and completes, confirmed
  via the admin overview page, not assumed from configuration alone.
- A file uploaded from Android exists on HP storage and is included in the next
  verified Restic snapshot without depending on the workstation being online.
- The Obsidian vault continues to synchronize only through Syncthing and is
  neither visible nor modified through Nextcloud.

### 5.2 Mirror GitHub repositories on HP

Files:

- add `modules/features/backup/github-mirror.nix`
- add a version-controlled repository-owner allowlist
- add the GitHub mirror preparation and validation script
- HP backup SOPS profile
- `hosts/hp-server/configuration.nix`

Configure a dedicated unprivileged `github-mirror` service account on HP that
maintains bare mirrors under `/var/lib/github-mirrors`. Root may read this path
for Restic, but ordinary users and unrelated services may not. The service is a
backup source preparer: it completes and validates all repository updates before
the Restic service snapshots the mirror directory.

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
- Every mirror and required Git LFS object set validates before Restic starts.
- No service on HP can push through the mirror credential.

### 5.3 Provision the Restic backup bucket and identity

Provider-side actions:

- [ ] Create the distinct `restic-backup` bucket and Restic prefix.
- [ ] Block all public access.
- [ ] Enable bucket versioning.
- [ ] Enable provider-side encryption in addition to Restic encryption.
- [ ] Create a dedicated HP backup identity scoped to the Restic
      bucket/prefix.
- [ ] Allow only the object/list operations Restic requires.
- [ ] Deny bucket-policy, ACL, public-access, and account-management changes.
- [ ] Deny permanent deletion of noncurrent object versions.
- [ ] Keep the administrative identity off all three machines and protect it
      with MFA and offline recovery codes.
- [ ] Configure a provider billing/budget alert. Note that bucket versioning
      plus daily snapshots with no lifecycle rules (deliberately deferred,
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

### 5.4 Implement the HP Restic module and consistent source backup

Files:

- add `modules/features/backup/restic-s3.nix`
- add version-controlled include/exclude files
- add a Nextcloud backup preparation/finalization script
- add a Hermes export preparation script (see below)
- consume the completed GitHub mirror manifest from 5.2
- `hosts/hp-server/configuration.nix`
- HP backup SOPS profile

Prefer NixOS's built-in `services.restic.backups` module. Add a thin wrapper
only for behavior that cannot be expressed by the built-in module.

Configure:

- root-run backup service
- S3 environment file and repository password file from SOPS
- daily persistent timer with randomized delay
- no `pruneOpts`, `forget`, or repository-deletion automation
- one-filesystem behavior where appropriate, with the mount layout from 5.1
  already verified so this flag cannot silently exclude the Nextcloud data
  directory
- structured journal output without secret values
- `/var/lib/restic-status/last-success` and
  `/var/lib/restic-status/last-source-status` timestamp/status files for later
  monitoring integration
- an explicit dependency on the HP data mount
- an explicit ordering/dependency on the successful GitHub mirror preparation
  service from 5.2; a failed mirror preparation prevents the Restic job from
  publishing a new successful snapshot marker
- sufficient free-space and mount-source checks before backup
- a consistent Nextcloud backup boundary: enable maintenance mode, create a
  database dump and recovery manifest, snapshot the required paths with
  Restic, and always disable maintenance mode in cleanup
- failure-safe cleanup so an interrupted backup does not leave Nextcloud in
  maintenance mode indefinitely
- a consistent Hermes export boundary using the same pattern as Nextcloud: if
  Hermes is a live service with its own on-disk state, do not snapshot that
  state directly. Use a Hermes-native export/checkpoint command, or a
  lock-file-gated copy that waits for Hermes to reach a quiescent point,
  before Restic runs — the same "dump before backup, never snapshot live
  state" rule applied to the database applies here.
- a Syncthing-quiescence check for the vault: query Syncthing's REST API
  (`/rest/db/status` for the vault folder) and confirm `"state": "idle"`
  before snapshotting the vault path. Do not rely on "the Syncthing process
  is running" as a proxy for "the folder is not mid-sync" — a running process
  can still have a folder in `syncing` or `scan-waiting` state.

Initial backup paths:

- the complete Nextcloud data directory on the dedicated HP filesystem
- the consistent Nextcloud database dump
- Nextcloud configuration, custom apps, themes, and encryption/recovery keys
  required by the selected configuration
- the HP Syncthing copy of the Obsidian vault, from its non-overlapping local
  path, only after the Syncthing idle check above passes
- the dedicated consistent Hermes export folder, only after the Hermes export
  boundary above completes successfully
- the complete `/var/lib/github-mirrors` tree and its validated repository
  manifest, only after the GitHub mirror preparation service succeeds
- reviewed HP service configuration/state that is not reproducible from Git,
  NixOS configuration, SOPS, or documented installation procedures

Initial excludes:

- unrelated OS downloads and desktop trash outside the Nextcloud data directory
- caches and thumbnails
- `node_modules`, build outputs, and dependency caches
- VM/container images and Docker data
- browser caches and transient profiles
- live database storage, because the consistent dump is backed up instead
- Redis/cache state, sockets, lock files, previews that can be regenerated, and
  temporary files
- Docker image/layer data; back up only reviewed persistent application state

Acceptance:

- The repository initializes without placing credentials in the Nix store.
- Two consecutive daily snapshots succeed.
- The second snapshot deduplicates unchanged data.
- The Nextcloud data directory's presence in the snapshot is verified
  directly (e.g. `restic ls` against the latest snapshot), not assumed from a
  successful exit code alone.
- The validated GitHub mirror manifest and representative bare repositories are
  present in the snapshot.
- No automatic command can delete old Restic snapshots or repository objects.
- A failed or interrupted preparation/backup run returns Nextcloud to service
  and records failure without updating the success timestamp.
- A failed or interrupted Hermes export leaves Hermes running normally and
  records failure without updating the success timestamp.

### 5.5 Track backup success separately from source freshness

Files:

- backup pre/post scripts in the Restic module
- Hermes export script/status file
- GitHub mirror preparation script/manifest/status file

Actions:

- [ ] Record successful creation and age of the Nextcloud database dump and
      recovery manifest.
- [ ] Record the HP data mount identity, available space, and Nextcloud data
      directory readability before each backup.
- [ ] Record the HP Syncthing vault path, readability, and synchronization
      status via the REST API idle check from 5.4; do not report the source
      set healthy while the vault has pending local writes or an unhealthy
      folder state.
- [ ] Record the age and validation result of the GitHub inventory, every
      repository mirror, and required LFS fetches. A truncated inventory,
      inaccessible repository, failed fetch, or failed `git fsck` degrades the
      overall source set and prevents a new successful backup marker.
- [ ] Record the age of the latest consistent Hermes export and whether the
      export boundary script completed successfully.
- [ ] Mark source status as degraded when the database dump, recovery manifest,
      Hermes export, or last fully validated GitHub mirror set exceeds 36 hours,
      or when the data filesystem approaches its reviewed free-space threshold.
- [ ] Update backup-success status only after Restic completes successfully.
- [ ] Do not equate `Restic exited successfully` with `all required recovery
inputs were current`.

Until monitoring is implemented, document a weekly manual check of the systemd
timer, latest snapshot, and the two status files.

Acceptance:

- A stale database dump or missing data mount prevents a falsely healthy
  Nextcloud backup result.
- An unreadable or unhealthy HP vault copy prevents a falsely healthy overall
  source-set result.
- A stale or failed Hermes export prevents a falsely healthy overall
  source-set result.
- A stale, incomplete, inaccessible, or invalid GitHub mirror set prevents a
  falsely healthy overall source-set result without deleting prior mirrors.
- A Restic failure does not update the success timestamp.
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
- [ ] Restore the Nextcloud data directory, database dump, configuration,
      custom apps/themes, and required keys to an isolated instance.
- [ ] Verify login plus listing, download, rename, upload, and deletion of
      disposable files in the isolated instance.
- [ ] Verify recovery using only the repository URL, restricted credentials,
      Restic password, this repository, and a fresh NixOS environment.
- [ ] Store verified offline copies of the Restic password, SOPS personal age
      key, provider recovery codes, and recovery instructions.
- [ ] Record the measured single-file and folder restore times.

No retention, pruning, lifecycle deletion, or Object Lock work begins here.
Those remain in the high-risk runbook.

Acceptance:

- The initial backup is not considered complete until the required Nextcloud,
  ordinary-file/folder, vault, and Git mirror restore tests pass.
- Recovery does not depend on the original HP server's Restic cache or
  decrypted local secret files.

## Phase 6: Migrate Nextcloud Files and Narrow Syncthing to the Vault

File:

- `modules/features/network/syncthing.nix`

### 6.1 Prepare and migrate the authoritative dataset

- [ ] Confirm the isolated Nextcloud restore passed before migration.
- [ ] Resolve existing Syncthing conflicts before changing topology.
- [ ] Inventory pre-existing same-name folders on Lenovo and HP.
- [ ] Move conflicting target content to dated quarantine directories rather
      than deleting or merging it automatically.
- [ ] Confirm HP destination capacity, workstation client capacity, and the
      expected Lenovo selective-sync set.
- [ ] Add explicit ignore patterns for caches, temporary data, and unsafe live
      databases.
- [ ] Confirm the vault has a healthy HP Syncthing copy and keep it outside the
      Nextcloud migration set.
- [ ] Pause Syncthing for each Nextcloud-bound folder immediately before its
      migration window so there is one writer and a stable source.

### 6.2 Migrate one folder at a time

Order:

1. `Documents`
2. `Pictures`
3. `Music`
4. `Shared`

For each folder:

- [ ] Upload from the reconciled workstation source through the Nextcloud
      client or supported WebDAV/API path; never copy directly into the server data
      directory.
- [ ] Wait for server-side completion and verify counts, representative hashes,
      names, timestamps, and browser access.
- [ ] Let the workstation Nextcloud client converge to a complete classic local
      copy where required; configure Lenovo selectively when it is online.
- [ ] Test create, edit, rename, conflict, and delete behavior with disposable
      files.
- [ ] Run and verify an HP Restic snapshot containing the migrated folder.
- [ ] Retire that folder from Syncthing on all peers only after the Nextcloud
      clients and off-site snapshot are verified. Preserve quarantined source data
      through the rollback window.
- [ ] Wait for completion before starting the next folder.

Do not run Syncthing and Nextcloud over the same live folder. Nextcloud trash
and versions are convenience features, not substitutes for Restic.

After those migrations, retain only the Obsidian `Vault` as the routine
personal Syncthing folder. Keep its HP peer enabled so the Restic source does
not depend on the workstation or an Android device being online. Any additional
Syncthing service export requires a separate reviewed path and purpose.

Acceptance:

- Nextcloud and intended offline client copies converge for each durable folder.
- The migrated Nextcloud folders are no longer shared by Syncthing, while the
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
- [ ] Keep live databases and mutable runtime state out of both Nextcloud and
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
- Nextcloud architecture, Android/browser/Linux access, MFA, break-glass
  recovery, bucket-credential isolation, and Nextcloud recovery material
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
- leaked S3, GitHub mirror, or AI-provider credentials
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

- [ ] Local login, sudo, SSH, Tailscale, Nextcloud client, Docker, printing, scanning,
      removable media, Vial, and monitor brightness work.
- [ ] Interactive AI credentials load automatically.
- [ ] Intended complete Nextcloud folders are locally available and virtual
      placeholders are not misreported as complete copies.

### Lenovo

- [ ] Local login, sudo, SSH, Tailscale, selective Nextcloud sync, printing, scanning,
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
- [ ] The Restic timer, consistent Nextcloud snapshot, status files, and restore
      tests pass; only root can read backup credentials.
- [ ] The GitHub mirror service discovers every allowlisted owner repository,
      validates Git and LFS data, cannot push, retains missing mirrors, and is
      included in the verified Restic snapshot.

### Remote files

- [ ] Browser, Linux desktop client/WebDAV, and Android client pass the full
      MFA enrollment and normal file-operation tests.
- [ ] No client or Nextcloud service account holds an S3 backup credential;
      unauthenticated access fails.
- [ ] An isolated restore of the Nextcloud database, configuration, keys, and
      local data directory completes from the Restic repository.

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
- Nextcloud: remove public DNS/proxy routing, revoke identity-provider sessions,
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
11. `storage(nextcloud): add local hp file service`
12. `backup(git): mirror github repositories on hp`
13. `backup(hp): add encrypted restic s3 snapshots`
14. `backup: add source state and restore checks`
15. `storage(nextcloud): migrate durable folders`
16. `backup: add consistent hermes export`
17. `docs: document security sync and recovery`

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
- [ ] Remote files are usable from browser, Linux, and Android after MFA, while
      the dedicated backup bucket remains unreachable outside Restic recovery.
- [ ] A clean-cache file and folder restore have succeeded.
- [ ] Every in-scope GitHub repository has a validated HP mirror in Restic, and
      a restored mirror can produce a working clone without GitHub access.
- [ ] No automatic retention, pruning, lifecycle expiration, or permanent
      backup deletion is enabled.
- [ ] Nextcloud is authoritative for `Documents`, `Pictures`, `Music`, and
      `Shared`; Syncthing remains exclusive to `Vault` and reviewed service
      exports; no synchronization roots overlap.
- [ ] Live Hermes databases are not synchronized; a tested consistent export
      is remotely backed up.
- [ ] Monitoring services and all high-risk work remain untouched.
- [ ] Documentation matches the implemented host roles and recovery process.
