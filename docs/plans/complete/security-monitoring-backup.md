# Security, Monitoring, and Remote Backup Plan

Status: Proposed

Created: 2026-07-29

Scope: `workstation`, `lenovo-yoga-pro-7`, and `hp-server`

## Goals

1. Make failures visible before they become data loss or prolonged downtime.
2. Reduce unnecessary network, credential, and service exposure.
3. Keep important files synchronized between all three NixOS machines.
4. Back up the synchronized dataset to encrypted remote S3-compatible storage.
5. Track kernel, disk-layout, retention/deletion, firmware, and hibernation
   changes in a separately approved high-risk runbook.
6. Make the HP server a reliable always-on monitoring and AI-agent host while
   keeping Hermes itself manually installed.

## Target Architecture

### Machine roles

| Machine | Role |
| --- | --- |
| `workstation` | Primary desktop, canonical remote-backup uploader, monitored node |
| `lenovo-yoga-pro-7` | Occasionally used mobile replica, monitored while online |
| `hp-server` | Always-on monitoring hub, manual Hermes/AI-agent host, Firecrawl host, and third Syncthing peer; not a backup repository |

The HP server should run Prometheus, Alertmanager, Grafana, Syncthing, SSH,
Tailscale, Docker-backed Firecrawl, and manually installed Hermes/AI agents.
Hermes must not be installed or packaged through NixOS or Home Manager. NixOS
may still provide its secrets, dependencies, firewall policy, health checks,
and an optional systemd supervisor that invokes the manually installed binary
from a stable path.

The HP can remain headless. Remove graphical services and desktop applications
that are not required by an agent workflow, but retain command-line
development tools, Git, tmux, Docker, and the runtimes actually used by the
agents.

### Data flow

```text
                         encrypted Restic repository
                       + S3 versioning and lifecycle
                                      ^
                                      |
                              daily backup upload
                                      |
                               [workstation]
                                  /       \
                       Syncthing /         \ Syncthing
                                /           \
                    [Lenovo laptop] <----> [HP server]
                                      sync
```

Syncthing provides availability and convenient cross-machine access. Restic
provides encrypted, versioned backups. Neither is treated as a substitute for
the other.

Live Hermes state is not synchronized blindly. HP produces a consistent,
periodic export into a dedicated Syncthing folder; the workstation then
includes that export in the remote Restic backup. This keeps S3 backup
credentials off HP while still protecting irreplaceable agent state remotely.

### Monitoring flow

```text
workstation exporter --------\
Lenovo exporter --------------> HP Prometheus --> Alertmanager --> notification
HP exporter ------------------/        |
                                        +--> Grafana over Tailscale

HP heartbeat -------------------------> external dead-man endpoint
```

An external heartbeat is required because monitoring hosted only on the HP
cannot report that the HP itself, the home network, or the monitoring stack is
down.

## Decisions to Confirm During Implementation

These are discovery gates, not architecture debates:

- The HP is expected to remain powered on and is treated as an always-on host.
- [ ] Choose AWS S3 or an S3-compatible provider after comparing storage,
  request, and restore-egress costs.
- [ ] Choose the notification receiver: email, an existing Telegram bot, or a
  generic webhook.
- [ ] Choose an external dead-man service for the HP heartbeat.

Provider choice must not change the local module interface. The backup module
should accept repository URL, credentials file, password file, paths, and
schedule as options. Retention/deletion options remain disabled until the
high-risk runbook is separately approved.

## High-Risk Work Is Out of Scope

Kernel parameters, initrd/resume configuration, partitioning, encryption
migration, swap, hibernation, destructive backup retention, S3 lifecycle
expiration, firmware updates, automatic deployments, and cleanup capable of
removing rollback generations are intentionally excluded from this plan.

They are isolated in
[High-Risk Storage, Hibernation, and System Changes](high-risk-storage-hibernation-system-changes.md).
That runbook requires a separate review and explicit approval before any
implementation begins. Completing this main plan does not require completing
the high-risk runbook.

## Phase 1: Immediate Security Baseline

### 1.1 Replace the shared initial password

Files:

- `modules/users/henhal.nix`
- `modules/features/secrets.nix`
- `.sops.yaml`
- a new host-appropriate SOPS secret file

Actions:

- [ ] Remove `initialPassword = "password"`.
- [ ] Store a strong password hash in SOPS and use a declarative
  `hashedPasswordFile`.
- [ ] Decide whether all hosts use the same local password. Prefer separate
  hashes so one machine does not expose the others.
- [ ] Audit the shared SSH authorized-key list and remove obsolete keys.
- [ ] Give authorized keys descriptive, current device comments.

Acceptance:

- New installations cannot log in with `password`.
- Local login and sudo work on all three hosts.
- SSH remains key-only.

### 1.2 Use practical secret profiles

Files:

- `modules/features/secrets.nix`
- `.sops.yaml`
- `secrets/`
- service modules consuming secrets

Security must not turn normal shell and agent use into repeated manual
decryption work. Use three understandable scopes rather than a separate secret
file for every small service:

| Profile | Recipients | Examples | Consumption |
| --- | --- | --- | --- |
| Shared interactive AI | personal keys and the NixOS hosts that need AI tools | OpenAI, Anthropic, Gemini, Ollama | automatically generated `interactive-ai.env`, sourced by the existing shell loader |
| HP agent services | personal keys and HP only | Hermes Telegram settings, agent-only tokens, Firecrawl configuration, monitoring notification secret | generated `hermes.env`, `firecrawl.env`, and monitoring environment files |
| Workstation backup | personal keys and workstation only | S3 access key, secret key, Restic password | root-readable systemd environment/credential files; never exported to the shell |

Actions:

- [ ] Preserve the convenient `load_secrets` workflow, but replace directory
  wildcard loading with an explicit allowlisted `interactive-ai.env`.
- [ ] Source `interactive-ai.env` automatically in interactive shells as
  today, with no per-login decryption command.
- [ ] Generate stable runtime environment files from SOPS at activation time.
- [ ] Make `hermes.env` readable by `henhal` on HP so the manually installed
  agent or its launcher can source it without sudo.
- [ ] Document one stable Hermes launch path that loads `hermes.env`; do not
  make the manual installation depend on a Nix store package.
- [ ] Keep backup and Grafana administrative credentials root-readable and
  pass them directly to systemd services.
- [ ] Keep shared AI keys off machines that do not use them, but accept that
  the HP intentionally needs provider credentials for background agents.
- [ ] Change Firecrawl's environment file from world-readable `0644` to
  root-only `0400` and pass it directly to the root-run Docker Compose service.
- [ ] Rotate credentials that were previously exposed too broadly after the
  new files are deployed.

Acceptance:

- Opening a normal shell still makes the intended AI API variables available.
- Starting manual Hermes requires at most one documented launcher command and
  no manual SOPS operation.
- `henhal` can read only the shared interactive and HP Hermes credentials that
  are intentionally needed.
- The HP cannot decrypt backup credentials.
- The Lenovo cannot decrypt HP-only Hermes or monitoring credentials.
- No secret-bearing file has mode `0644`.

### 1.3 Tighten SSH, firewall, and privileged services

Files:

- `modules/features/network/ssh-server.nix`
- `modules/features/network/tailscale.nix`
- `modules/base.nix`
- host configurations

Actions:

- [ ] Keep password and root SSH login disabled.
- [ ] Re-enable PAM account/session handling while retaining key-only
  authentication.
- [ ] Remove the hand-maintained cipher and key-exchange lists unless a
  compatibility requirement is documented; follow the OpenSSH defaults.
- [ ] Reduce fail2ban retry limits from the current ineffective value or remove
  fail2ban on hosts whose SSH is Tailscale-only.
- [ ] Replace blanket trust of `tailscale0` with per-interface allowed ports.
- [ ] Bind monitoring and administration services to loopback or Tailscale,
  never `0.0.0.0` on the LAN without a documented reason.
- [ ] Move Docker out of `base.nix`; enable it explicitly on HP for Firecrawl
  and on any other host with a current Docker workload.
- [ ] Treat membership in the `docker` group as root-equivalent and remove it
  where Docker is disabled.
- [ ] Remove the global insecure QtWebEngine exception or document and isolate
  the application that still requires it.

Acceptance:

- A port inventory matches the explicit NixOS firewall declarations.
- Grafana, Prometheus, Alertmanager, and exporters are reachable through
  Tailscale only.
- The workstation and Lenovo retain the remote-access paths actually used.

## Phase 2: Monitoring Foundation

Implement monitoring before backup so backup jobs emit metrics and alerts from
their first production run.

### 2.1 Replace the existing server monitoring module

Files:

- replace or refactor `modules/features/network/server-monitoring.nix`
- add `modules/features/network/monitoring-exporter.nix`
- add `modules/features/network/monitoring-hub.nix`
- add version-controlled Grafana dashboards and Prometheus alert rules

The current module must not be enabled as-is because it has a hardcoded Grafana
password and opens monitoring ports globally.

### 2.2 Export metrics from all hosts

Enable Prometheus Node Exporter with at least:

- CPU, load, memory, network, filesystem, disk statistics, and hardware sensors
- systemd unit state
- textfile collector for locally generated health metrics

Add textfile metrics for:

- last successful Restic backup timestamp
- last successful Restic repository check
- Syncthing pending/out-of-sync item count
- failed systemd unit count
- Nix store size and generation age
- SMART/NVMe health summary
- battery health and charge capacity on the Lenovo
- Hermes process/service health and last successful agent health probe
- Firecrawl API health, container restart count, and request failures
- HP agent CPU, memory, and sustained load

Exporter listeners must be reachable only through Tailscale.

### 2.3 Run the monitoring hub on the HP

Configure:

- Prometheus with 30 days of local retention
- Alertmanager with one declared receiver
- Grafana bound to loopback and exposed using Tailscale Serve or a
  Tailscale-only listener
- SOPS-managed Grafana credentials
- declaratively provisioned Prometheus data source and dashboards
- persistent journald storage with bounded disk usage

Provision dashboards for:

1. Fleet overview
2. CPU, memory, temperature, and storage
3. Systemd failures and reboots
4. Syncthing health
5. Backup freshness and repository checks
6. Lenovo battery health

Grafana supports provisioning data sources and dashboards from files, which
keeps the monitoring configuration reviewable in Git.

### 2.4 Alert policy

Initial alerts:

| Alert | Warning | Critical |
| --- | --- | --- |
| Filesystem usage | above 80% for 1 hour | above 90% for 15 minutes |
| SMART/NVMe health | any warning | failing health status |
| Failed systemd units | one for 15 minutes | security/backup unit failed |
| Memory pressure | sustained swap/pressure | repeated OOM event |
| Workstation backup age | above 36 hours | above 72 hours |
| Repository check age | above 35 days | above 45 days |
| Syncthing backlog | non-zero for 24 hours | increasing for 72 hours |
| HP monitoring heartbeat | missing 15 minutes | missing 30 minutes |
| Lenovo last seen | informational after 14 days | warning after 30 days |
| Hermes health | failed probe for 10 minutes | process absent/restart loop |
| Hermes export age | older than 36 hours | older than 72 hours |
| Firecrawl health | failed probe for 10 minutes | unavailable for 30 minutes |
| HP agent load | sustained high load for 30 minutes | thermal or memory pressure |

Do not alert immediately when the Lenovo is offline; that is normal. Do alert
when it has been absent long enough to miss updates, sync, and health checks.

### 2.5 External dead-man check

- [ ] Send a heartbeat after Prometheus and Alertmanager health checks pass.
- [ ] Send a separate heartbeat after the daily backup succeeds.
- [ ] Configure the external service to notify when either heartbeat is late.
- [ ] Verify notification delivery by intentionally withholding one heartbeat.

Acceptance:

- Every host appears in Grafana while online.
- An intentionally stopped exporter produces one actionable alert.
- The HP going offline produces an external alert.
- Alerts contain host, failure, severity, and a short remediation hint.

## Phase 3: Three-Way Sync and Remote S3 Backup

### 3.1 Define the synchronized dataset

File:

- `modules/features/network/syncthing.nix`

Default durable dataset shared by all three machines:

- `Documents`
- `Pictures`
- `Music`
- `Vault`
- `Shared`

Keep disposable or device-specific data out unless explicitly requested:

- `Downloads`
- caches and build outputs
- VM images
- browser caches
- `node_modules`
- application databases that are unsafe to synchronize live

Actions:

- [ ] Confirm HP and Lenovo capacity before expanding the topology.
- [ ] Add all three machines as participants in each durable folder.
- [ ] Add explicit ignore patterns for caches, temporary files, and
  application-specific conflict-prone databases.
- [ ] Roll out one folder at a time, beginning with `Vault` and `Documents`.
- [ ] Confirm that permissions, conflicts, and delete propagation behave as
  expected before adding the next folder.

Acceptance:

- A test file created, edited, and deleted on each host converges correctly.
- A forced conflict creates a recoverable Syncthing conflict file.
- The full durable dataset reports synchronized on all online hosts.

### 3.2 Use Restic for client-side encrypted remote backup

Files:

- add `modules/features/backup/restic-s3.nix`
- add host-scoped SOPS backup secrets
- import the module from `hosts/workstation/configuration.nix`

The workstation is the canonical uploader for the synchronized dataset. This
avoids paying to upload three identical copies while Restic still preserves
versioned snapshots remotely.

The module should provide:

- a root-run, sandboxed systemd backup service
- a persistent daily timer with randomized delay
- a monthly repository-check timer
- sleep inhibition while a backup is active
- a textfile metric updated only after success
- `OnFailure` integration with monitoring
- explicit include and exclude files stored in Git
- SOPS-provided repository password and S3 credentials

Run metadata checks monthly. Run a sampled data read regularly and a full
repository read after initial upload, after backend changes, and at least
annually, accounting for provider egress costs.

This phase creates snapshots but does not automate `forget`, `prune`, or any
other repository deletion. Retention and deletion activation belong to the
separate high-risk runbook.

### 3.3 Secure the S3 bucket

One-time provider-side configuration:

- [ ] Create a dedicated bucket used only for Restic.
- [ ] Block all public access.
- [ ] Enable bucket versioning.
- [ ] Enable provider-side encryption in addition to Restic client encryption.
- [ ] Create a dedicated backup identity limited to the Restic prefix.
- [ ] Deny bucket-policy, ACL, public-access, and account-management changes.
- [ ] Deny permanent deletion of noncurrent object versions to the backup
  identity.
- [ ] Keep the administrative identity separate, protected by MFA, and absent
  from all three machines.
- [ ] Do not move live Restic repository objects into an archival storage class
  without testing restore behavior and retrieval delays.

No lifecycle expiration, permanent-version deletion, Object Lock, or automated
retention policy is enabled in this main plan. Those changes can destroy backup
history or create irreversible bucket behavior and are covered by the
high-risk runbook.

### 3.4 Restore testing

A backup is complete only after restoration has been tested.

- [ ] Restore one file to a temporary directory after the first backup.
- [ ] Restore one complete folder after the first backup.
- [ ] Perform a quarterly random-file restore.
- [ ] Perform an annual full restore drill to separate storage.
- [ ] Document recovery using only:
  - a fresh NixOS machine
  - the Restic repository password
  - restricted S3 credentials
  - this repository
- [ ] Store an offline copy of the Restic password and personal SOPS age key.

Acceptance:

- Daily backup runs without an interactive shell.
- A missed backup produces an alert.
- Deleting a local test file does not prevent restoring an older snapshot.
- A restore succeeds on a machine without the original Restic cache.

## Phase 4: HP Agent and Monitoring Host

File:

- `hosts/hp-server/configuration.nix`

### 4.1 Preserve the manual Hermes boundary

- [ ] Install and update the Hermes executable manually using its supported
  upstream method.
- [ ] Do not declare the Hermes package through NixOS or Home Manager. A manual
  upstream install or non-declarative user profile remains acceptable.
- [ ] Choose and document a stable executable path.
- [ ] Let NixOS manage only supporting concerns: secrets, dependencies,
  firewall, health checks, logging, and optionally a systemd unit that invokes
  the manual executable.
- [ ] If NixOS manages the unit, add a pre-start check with a clear error when
  the manual executable is missing or incompatible.
- [ ] Monitor process state, restart count, health endpoint, and resource use.
- [ ] Keep Hermes data/state out of Syncthing unless upstream confirms it is
  safe to synchronize live.
- [ ] Define a periodic, consistent export of irreplaceable Hermes
  configuration or agent memory into a dedicated Syncthing folder.
- [ ] Let the workstation include that exported snapshot—not the live Hermes
  database/state directory—in the remote Restic backup.
- [ ] Alert when the most recent Hermes export is older than its expected
  schedule.

This keeps the unreliable installation boundary manual without giving up
declarative secrets, service supervision, or monitoring.

### 4.2 Keep and harden Firecrawl

Firecrawl remains required by Hermes.

- [ ] Retain Docker and the Firecrawl systemd/Compose integration on HP.
- [ ] Bind the Firecrawl API to `127.0.0.1` when only local Hermes consumes it.
- [ ] Do not publish the Playwright container port to the host unless an
  external consumer is documented; use the internal Compose network.
- [ ] Use a root-only SOPS-rendered `firecrawl.env`.
- [ ] Add container health checks and Prometheus/textfile metrics.
- [ ] Pin or deliberately record the upstream Firecrawl revision so a restart
  cannot silently move to incompatible upstream code.
- [ ] Separate mutable Firecrawl source/state from the dotfiles checkout.

### 4.3 Fix the Firecrawl Git checkout issue

The current `.firecrawl-src` path is a tracked Git link without a corresponding
`.gitmodules` entry. It also mixes a mutable upstream clone with the declarative
dotfiles repository.

Planned resolution:

1. Remove the `.firecrawl-src` Git-link entry from the dotfiles repository.
2. Do not add Firecrawl as a dotfiles submodule.
3. Move the mutable upstream checkout to a dedicated path such as
   `/var/lib/firecrawl/source`.
4. Keep only the NixOS module and Compose override in this repository.
5. Make the bootstrap service fetch the configured revision into the dedicated
   path and fail clearly if checkout/update fails.
6. Record the deployed revision as a metric and in service logs.
7. Test first boot from a clean machine state, normal restart, deliberate
   revision update, and rollback.

Acceptance:

- A fresh dotfiles clone has no broken or dirty submodule state.
- Firecrawl can bootstrap without writing inside the dotfiles checkout.
- Firecrawl restarts reproducibly at the configured upstream revision.
- Hermes reaches Firecrawl over loopback without exposing it to the LAN.

### 4.4 Reduce unrelated HP desktop configuration

Remove unless an agent workflow demonstrably needs it:

- SDDM and Niri
- desktop foundation and desktop utilities
- GUI applications and browsers
- PipeWire, Bluetooth, printing, and removable-media desktop helpers
- virtualization unless it supports an agent workload

Review rather than automatically remove:

- Hermes Dashboard
- Hermes Workspace
- browser automation dependencies
- GPU/compute support

Retain a component when the manually installed agent actively depends on it,
then monitor and document that dependency.

Keep:

- minimal base and user
- SSH
- Tailscale
- Syncthing
- Docker and Firecrawl
- manual Hermes/AI-agent runtime dependencies
- Git, tmux, and required development tools
- monitoring exporter
- Prometheus, Alertmanager, and Grafana
- SOPS with shared interactive AI and HP service credentials
- storage-health and maintenance services
- laptop lid-close server behavior

Replace the unconditional `performance` governor with a balanced default.
Allow a monitored, time-bounded performance mode for demanding agent jobs if
measurements show it is needed.

Acceptance:

- HP boots to `multi-user.target` without a display manager.
- Manually installed Hermes starts through the documented launch path and can
  access only its intended environment file.
- Firecrawl is healthy, revision-pinned, and reachable by Hermes over loopback.
- Monitoring and Syncthing are reachable only through intended interfaces.
- Sustained agent workloads do not produce unmonitored thermal, memory, or disk
  pressure.
- Idle power, temperature, and memory usage are recorded before and after the
  reduction.

## Phase 5: Maintenance, Updates, and Validation

### System maintenance

Add safe, observational maintenance first:

- SMART/NVMe health monitoring without automatic repair actions
- bounded persistent journald storage
- alerts for low disk space, excessive Nix store growth, and stale firmware

SSD discard policy, firmware updates, garbage collection, store rewriting, and
other storage-mutating maintenance are deferred to the high-risk runbook.

### Update workflow

- [ ] Add CI evaluation/build checks for all three NixOS configurations.
- [ ] Add a scheduled flake-lock update PR rather than silently updating live
  machines.
- [ ] Require successful host builds before deployment.
- [ ] Keep switching and rebooting manual on all hosts in this plan.
- [ ] Alert when a machine has not deployed a successful configuration within
  the agreed update window.

### Documentation

Update:

- `README.md`
- `docs/HOSTS.md`
- `docs/FEATURES.md`
- `docs/SECRETS.md`

Document:

- HP's monitoring-hub role
- the manual Hermes installation boundary and stable launch procedure
- Firecrawl source revision, update, rollback, and health-check procedure
- the distinction between sync and backup
- S3 recovery steps
- the boundary between this safe plan and the separate high-risk runbook
- monitoring endpoints and alert routing
- credential rotation and host decommissioning

## Proposed Implementation Order and Commits

Each step should be independently reviewable and reversible:

1. `security: replace initial password and scope secrets`
2. `security: restrict ssh firewall and privileged services`
3. `monitoring: add fleet exporters`
4. `monitoring: rebuild hp monitoring hub`
5. `server: fix firecrawl checkout and secret handling`
6. `server: supervise and monitor manual hermes`
7. `sync: extend durable folders to all nixos hosts`
8. `backup: add encrypted restic s3 backups`
9. `backup: add health metrics alerts and restore drill`
10. `server: remove unrelated hp desktop services`
11. `monitoring: add storage health and lifecycle alerts`
12. `docs: align host security backup agent and monitoring docs`

High-risk commits are intentionally absent. They are sequenced only in the
dedicated runbook after separate approval.

## Definition of Done

- [ ] Important files converge between all three machines.
- [ ] The workstation produces encrypted daily remote snapshots.
- [ ] Remote backups have versioning, lifecycle protection, and restricted IAM.
- [ ] A real restore has succeeded from documented recovery material.
- [ ] Backup and repository-check freshness are visible and alerting.
- [ ] All online machines expose system, disk, and service health through
  Tailscale only.
- [ ] The HP reports fleet status and has an external dead-man check.
- [ ] Manual Hermes and Firecrawl are healthy, monitored, and available without
  exposing Firecrawl to the LAN.
- [ ] Firecrawl no longer creates broken Git-link state in the dotfiles
  checkout.
- [ ] Unrelated HP desktop services are gone.
- [ ] Secrets and local passwords use the documented practical profiles.
- [ ] Intended AI secrets remain automatically available to shells and Hermes
  without exposing backup or monitoring administration credentials.
- [ ] No kernel, initrd, resume, partition, swap, firmware, destructive
  retention, automatic deployment, or rollback-generation cleanup change was
  introduced through this plan.
- [ ] The configuration and documentation agree.

## References

- [Restic: preparing an S3 repository](https://restic.readthedocs.io/en/v0.15.1/030_preparing_a_new_repo.html)
- [AWS: S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [Prometheus: Node Exporter](https://prometheus.io/docs/guides/node-exporter/)
- [Prometheus: Alertmanager notification routing](https://prometheus.io/docs/alerting/latest/notifications/)
- [Grafana: declarative provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)
