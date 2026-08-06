# Security Monitoring Implementation Plan

Status: Implemented

Created: 2026-08-05

Completed: 2026-08-06

Scope: Comprehensive monitoring for `hp-server`, `workstation`, and
`lenovo-yoga-pro-7`, with `hp-server` as the monitoring hub and a private,
authenticated Grafana dashboard available at `https://monitor.henhal.net`.

Source plans:

- [Security, Monitoring, and Remote Backup](security-monitoring-backup.md)
- [Security, Organization, Sync, and Backup Implementation](security-backup-implementation.md)

## Objective

Implement the monitoring portion deferred by the completed security and backup
plan. The finished system must make hardware trouble, service failures, backup
failures, public-service outages, synchronization problems, and loss of the HP
server visible before they become prolonged downtime or data loss.

The implementation will provide:

- Prometheus metrics from all three NixOS machines over Tailscale
- centralized, bounded systemd journal logs in Loki
- Grafana dashboards provisioned from this repository
- Prometheus alert rules with actionable severity and remediation annotations
- Alertmanager notifications through a SOPS-managed receiver
- an external dead-man heartbeat that detects failure of HP, the home internet
  connection, or the entire local monitoring stack
- black-box probes of `cloud.henhal.net`, `auth.henhal.net`, and
  `monitor.henhal.net` from HP
- backup, Syncthing, OpenCloud, Keycloak, Cloudflare Tunnel, Firecrawl, Hermes,
  storage, NixOS, and laptop-battery monitoring
- a browser-accessible dashboard at `monitor.henhal.net`, published through the
  existing outbound-only Cloudflare Tunnel and protected by Keycloak MFA

This document is the completed implementation record. It does not authorize automatic
repairs, reboots, upgrades, retention deletion, filesystem repair, SMART tests,
or other destructive maintenance.

## Completion Summary

The implementation landed across commits `e6024ee`, `aed90d0`, `751e9d8`, and
`41ca813`. Commit `572a178` supplied the HP memory safeguards needed to operate
the stack reliably on the existing hardware.

The deployed system includes the three-host exporter configuration, HP-hosted
Prometheus, Alertmanager, Grafana, Loki, Alloy journal forwarding, Blackbox
Exporter, repository-provisioned rules and dashboards, Keycloak OIDC,
Cloudflare Tunnel ingress, Telegram notifications, and two independent
Healthchecks.io heartbeats. Process Exporter was added during dashboard
refinement to provide bounded per-executable CPU and resident-memory drill-down.

Live deployment verified Grafana login, dashboards, Telegram firing/resolved
messages, monitoring-stack and backup heartbeats, HP/workstation metrics, Loki
log ingestion, local collectors, public probes, Restic snapshots, and a sampled
repository check. Lenovo remains an intermittently online target by design; its
configuration builds successfully and its runtime metrics appear when it is
online and rebuilt with the current generation.

Two known conditions are intentionally visible but do not notify Telegram:

- Hermes backup source health remains degraded until a reviewed native export
  command exists.
- `NixStoreLarge` remains deferred until the separate storage-capacity work is
  resumed.

These conditions are routed to Alertmanager's `local-null` receiver rather than
being hidden or falsely reported as healthy.

## Fixed Architecture Decisions

### Machine roles

| Machine | Monitoring role |
| --- | --- |
| `hp-server` | Prometheus, Alertmanager, Grafana, Loki, Blackbox Exporter, Node/Process Exporters, local log collector, metric generators, and dead-man heartbeat sender |
| `workstation` | Node/Process Exporters, local log collector, and host-specific metric generators while online |
| `lenovo-yoga-pro-7` | Node/Process Exporters, local log collector, battery metrics, and host-specific metric generators while online |

### Traffic and trust boundaries

```text
workstation Node/Process Exporters --\
workstation Alloy ----------+-- Tailscale only --> hp-server
Lenovo Node/Process Exporters +                    Prometheus
Lenovo Alloy ---------------+                     Loki
HP Node/Process Exporters --/                        |
                                                     +--> Alertmanager --> notification receiver
Public HTTPS endpoints --> Blackbox Exporter --------+
                                                     |
                                                     +--> Grafana on 127.0.0.1:3000
                                                               |
Cloudflare --> existing outbound Tunnel --> monitor.henhal.net -+
                                                               |
                                                        Keycloak OIDC + MFA

HP health + nightly backup success --> external dead-man service
```

Only Grafana is published through Cloudflare Tunnel. Prometheus, Alertmanager,
Loki, exporter, Alloy, and Blackbox Exporter HTTP endpoints must never be added
to public DNS or Cloudflare ingress.

Prometheus scrapes remote machines over their stable Tailscale DNS names or
Tailscale IP addresses. Their metric and log-ingestion ports are permitted only
on `tailscale0`. No monitoring port is opened globally or on the physical LAN.

### Public dashboard access

Use these values:

| Setting | Value |
| --- | --- |
| Public URL | `https://monitor.henhal.net` |
| Local Grafana origin | `http://127.0.0.1:3000` |
| OIDC issuer | `https://auth.henhal.net/realms/monitoring` |
| Keycloak realm | `monitoring` |
| Keycloak client ID | `grafana` |
| OAuth callback | `https://monitor.henhal.net/login/generic_oauth` |
| Logout redirect | `https://monitor.henhal.net/` |

Create a separate Keycloak `monitoring` realm instead of coupling infrastructure
administration to the OpenCloud realm. Keep one routine administrator and one
tested break-glass administrator. Require TOTP and recovery codes for both.

Grafana must use Keycloak Generic OAuth, disable anonymous access, disable
self-service sign-up outside OAuth, and map only an explicit Keycloak role to
Grafana administrator. A routine viewer account should receive the Grafana
Viewer role. Do not use email address alone for privilege mapping.

Set Grafana's canonical `root_url` to `https://monitor.henhal.net/`, enable
secure and SameSite cookies, and honor only the proxy headers supplied by the
local Cloudflare Tunnel path. Retain a randomly generated, SOPS-managed local
Grafana server-administrator password for break-glass recovery; routine access
must use Keycloak. Test the local credential after deployment and keep it out of
the browser password autofill used for routine login.

Cloudflare Access is not required in the first implementation because Keycloak
already provides MFA and role-aware application authentication. It may be added
later as a separate reviewed defense-in-depth change. Cloudflare caching must be
bypassed for `monitor.henhal.net`.

### Monitoring components

Use the NixOS-packaged services and pin their versions through `flake.lock`:

- Prometheus for metrics and alert evaluation
- Alertmanager for grouping, inhibition, and notifications
- Grafana OSS for dashboards and investigation
- Loki in single-binary mode with local filesystem storage for journal logs
- Grafana Alloy on each host to send selected journal logs to Loki
- Prometheus Node Exporter on each host
- Prometheus Process Exporter on each host, grouped only by executable name
- Prometheus Blackbox Exporter on HP for HTTP/TLS probes
- smartctl-based textfile metrics for local disk health
- small root-run metric generators for backup and service-specific status

Do not add Mimir, Tempo, Pyroscope, Elasticsearch, Kubernetes, or a remote
Grafana Cloud dependency. They add operational cost without improving the
initial three-host use case.

### Storage and retention

Monitoring data is operational and is not part of the irreplaceable backup set.
It may be recreated after a disaster. Store it on HP's system disk, not the T7
OpenCloud data filesystem and not in the R2 Restic repository.

Initial limits:

- Prometheus: 30 days or 15 GiB, whichever is reached first
- Loki: 14 days, with a 10 GiB target ceiling
- persistent journald on every host: bounded by host role; 2 GiB on HP and
  1 GiB on desktop/laptop hosts
- Grafana database and provisioning state: local; dashboards remain canonical
  in Git

Set both time and size limits where the packaged service supports them. Add
alerts at 70%, 80%, and 90% utilization of the filesystem holding monitoring
data. Do not put monitoring storage on an unbounded Docker volume.

### Notification and external-heartbeat decisions

The module interface must not depend on one provider. The first deployment uses:

- primary alerts: the existing Telegram bot path, with a dedicated monitoring
  bot token or a dedicated chat/topic and explicit allowed recipient
- external dead-man: Healthchecks.io or an equivalent independent hosted
  heartbeat service
- optional secondary alerts: email, added only after the primary path is proven

The dead-man service must be outside the house and outside HP. A self-hosted
heartbeat on HP cannot report the loss of HP, power, or the home network.

Before Phase 4, create the selected provider account and collect two distinct
heartbeat URLs: one for monitoring-stack health and one for nightly backup
success. Store notification credentials and heartbeat URLs in SOPS; never put
them in Nix expressions, shell history, Grafana dashboard JSON, or the Nix store.

## Security Requirements

- Grafana binds only to `127.0.0.1:3000`.
- Prometheus, Alertmanager, Loki, Blackbox Exporter, and Alloy administrative
  endpoints bind to loopback on HP unless a specific Tailscale listener is
  required.
- Loki's remote push receiver is the one required Tailscale listener. Restrict
  its port to `tailscale0`; keep Loki readiness, query, and administrative
  access on loopback or behind a local proxy that accepts only the Alloy push
  path from the tailnet.
- Node and Process Exporters on workstation and Lenovo listen on the Tailscale address or
  is restricted by the `tailscale0` firewall to HP as far as NixOS firewall
  rules allow.
- Loki ingestion from remote hosts is Tailscale-only. Do not accept unauthenticated
  log pushes on LAN or public interfaces.
- Prometheus and Loki data sources use Grafana server-side proxy access; the
  browser never connects to backend ports directly.
- Grafana secrets are supplied with systemd credentials or environment files
  generated by sops-nix, not interpolated into world-readable Nix store files.
- Keycloak client secrets, Alertmanager receiver secrets, and heartbeat URLs
  live in `secrets/monitoring.yaml`, encrypted for personal recipients and HP.
- Exported metrics must not contain API tokens, passwords, full command lines
  containing secrets, private file contents, or high-cardinality path labels.
- Process metrics are aggregated by executable command name with thread metrics
  disabled; they never label by PID, command line, argument, or executable path.
- Alloy must read only the system journal. Do not grant it blanket read access
  to home directories or secret directories.
- Loki labels are limited to stable fields such as `host`, `unit`, `priority`,
  and `transport`. Never label by message, PID, request path, user ID, token, or
  other unbounded values.
- Grafana plugins are disabled unless pinned and reviewed. Analytics and update
  checks are disabled where supported.
- Alert annotations include commands and runbook links, but no credentials.
- The dashboard hostname must not proxy Grafana until OIDC is configured and a
  local authenticated login test has passed.

## Repository Layout

Create or refactor these files during implementation:

```text
modules/features/monitoring/
├── exporter.nix
├── hub.nix
├── metrics/
│   ├── backup-status.sh
│   ├── nixos-health.sh
│   ├── service-health.sh
│   ├── storage-health.sh
│   └── syncthing-health.sh
├── rules/
│   ├── availability.yaml
│   ├── backup.yaml
│   ├── host.yaml
│   ├── services.yaml
│   └── storage.yaml
├── alloy/
│   └── journal.alloy
└── dashboards/
    ├── fleet-overview.json
    ├── hp-services.json
    ├── backup-and-sync.json
    ├── storage-and-hardware.json
    └── logs.json

secrets/monitoring.yaml
docs/MONITORING.md
docs/runbooks/monitoring-alerts.md
docs/runbooks/monitoring-recovery.md
```

Replace `modules/features/network/server-monitoring.nix`; do not keep its
hardcoded password, public listeners, or global firewall rules. Either delete
the obsolete file after imports have migrated or turn it into a temporary
compatibility import that emits a deprecation warning and imports the new hub.
The preferred final state is deletion.

## Module Interfaces

### `monitoring-exporter.nix`

Expose one reusable module as `flake.nixosModules.monitoringExporter`:

```nix
my.monitoring.exporter = {
  enable = true;
  hubHost = "hp-server";
  tailscaleInterface = "tailscale0";
  enableJournalShipping = true;
  enableSmart = true;
  enableBattery = false;
  extraUnits = [];
};
```

The module must:

- enable Node Exporter with `cpu`, `diskstats`, `filesystem`, `loadavg`,
  `meminfo`, `netdev`, `processes`, `systemd`, `textfile`, `time`, `uname`, and
  `hwmon` collectors when supported
- enable Process Exporter on port `9256`, grouped by executable command name
  with per-thread metrics disabled
- enable a dedicated textfile directory such as
  `/var/lib/prometheus-node-exporter-text-files`
- create textfile metric jobs using atomic write-then-rename publication
- enable Alloy journal forwarding when requested
- bind or firewall exporter and log-shipping traffic to Tailscale
- expose no public port and add no global `allowedTCPPorts`
- provide host labels from Prometheus scrape configuration, not as labels on
  every generated metric line
- fail evaluation if enabled without Tailscale on a remote node

`enableBattery` is true only on Lenovo. `extraUnits` supplies a host-specific
allowlist of systemd services to report on dashboards; generic failed-unit
metrics still cover all units.

### `monitoring-hub.nix`

Expose the HP module as `flake.nixosModules.monitoringHub`:

```nix
my.monitoring.hub = {
  enable = true;
  publicHost = "monitor.henhal.net";
  authHost = "auth.henhal.net";
  oidcRealm = "monitoring";
  oidcClientId = "grafana";
  scrapeTargets = {
    hp-server = "hp-server";
    workstation = "workstation";
    lenovo-yoga-pro-7 = "lenovo-yoga-pro-7";
  };
  prometheusRetention = "30d";
  lokiRetention = "14d";
};
```

The module must:

- enable Prometheus, Alertmanager, Grafana, Loki, Blackbox Exporter, and HP's
  exporter
- provision Prometheus and Loki as Grafana data sources
- provision every dashboard and alert rule from repository files
- add recording rules for fleet availability, backup age, disk pressure, and
  service health where repeated expressions would otherwise be expensive
- configure stable scrape jobs and labels
- expose only Grafana to the Cloudflare tunnel module
- include assertions for hostname, OIDC secret, notification receiver, and
  nonempty scrape targets
- create bounded monitoring storage and persistent-journal configuration
- configure systemd ordering without introducing circular dependencies
- configure Grafana's public root URL, proxy behavior, secure cookies, and
  break-glass local administrator without writing either OAuth or administrator
  secrets into the Nix store

### Cloudflare Tunnel extension

Refactor `modules/features/network/cloudflare-tunnel.nix` so the existing tunnel
can publish optional, explicitly declared HTTP services without coupling every
hostname to `my.opencloud.enable`.

The final interface should preserve the current OpenCloud and Keycloak routes
and add the monitoring route:

```nix
my.opencloudTunnel = {
  tunnelId = "d5383138-72c4-4879-924a-319edc4c20c6";
  monitoringHost = "monitor.henhal.net";
};
```

Alternatively, rename the module to a generic `cloudflareTunnel` while keeping a
compatibility option for the current tunnel ID. Do not require a new tunnel or
new credential merely to add Grafana. The ingress map must remain declarative:

- `cloud.henhal.net` -> `http://127.0.0.1:9200`
- `auth.henhal.net` -> `http://127.0.0.1:8080`
- `monitor.henhal.net` -> `http://127.0.0.1:3000`
- default -> `http_status:404`

The tunnel UUID is an identifier and may remain plain text. The tunnel
credential JSON remains a SOPS secret.

## Metric Contract

Custom metrics are a public interface between scripts, Prometheus rules, and
Grafana. Define them before dashboard work and cover their output with tests.

Use the prefix `henhal_` for locally generated metrics. At minimum publish:

| Metric | Type | Meaning |
| --- | --- | --- |
| `henhal_backup_last_success_timestamp_seconds{repository="hp-offsite"}` | gauge | Completion time of the latest successful Restic snapshot |
| `henhal_backup_snapshot_age_seconds{repository="hp-offsite"}` | gauge | Current age of the latest snapshot |
| `henhal_backup_repository_check_last_success_timestamp_seconds` | gauge | Latest successful repository check |
| `henhal_backup_source_healthy{source="..."}` | gauge | Health from staged backup status JSON |
| `henhal_backup_source_status_timestamp_seconds{source="..."}` | gauge | Freshness of the source status record |
| `henhal_syncthing_folder_in_sync{folder="vault|shared"}` | gauge | Folder completion and error summary |
| `henhal_syncthing_pending_items{folder="vault|shared"}` | gauge | Pending item count without file-name labels |
| `henhal_nixos_generation_timestamp_seconds` | gauge | Build time of the active system generation |
| `henhal_nix_store_bytes` | gauge | Current Nix store disk usage |
| `henhal_system_failed_units` | gauge | Number of failed units |
| `henhal_storage_smart_healthy{device="..."}` | gauge | Normalized SMART/NVMe overall health |
| `henhal_storage_temperature_celsius{device="..."}` | gauge | Drive temperature when available |
| `henhal_battery_capacity_ratio` | gauge | Lenovo full-charge capacity divided by design capacity |
| `henhal_service_probe_success{service="..."}` | gauge | Safe local health probe result |
| `henhal_service_restart_count{service="..."}` | gauge | Restart count for important services |
| `henhal_public_tls_expiry_timestamp_seconds{host="..."}` | gauge | TLS expiry derived from black-box probe data or a local probe |
| `henhal_monitoring_config_build_info{revision="..."}` | gauge | Deployed monitoring configuration revision |

The backup collector reads existing status sources rather than duplicating
backup logic:

- `/var/lib/restic-status/opencloud-source.json`
- `/var/lib/restic-status/opencloud-identity.json`
- `/var/lib/restic-status/vault.json`
- `/var/lib/restic-status/shared.json`
- `/var/lib/restic-status/hermes.json`
- `/var/lib/github-mirrors/status.json`
- the latest Restic snapshot timestamp via the existing root-only
  `restic-hp-offsite` wrapper or a root-run post-success hook

Collectors must convert missing, invalid, stale, or degraded JSON into explicit
zero-valued health metrics and a nonzero collector-error metric. They must not
silently retain a healthy old `.prom` file after a failed refresh.

## Scrape and Log Collection Design

### Prometheus scrape jobs

Create these jobs with stable labels:

| Job | Targets | Interval |
| --- | --- | --- |
| `node` | all three machines | 30 seconds |
| `process` | all three machines | 30 seconds |
| `prometheus` | HP loopback | 30 seconds |
| `alertmanager` | HP loopback | 30 seconds |
| `loki` | HP loopback | 30 seconds |
| `grafana` | HP loopback metrics endpoint | 30 seconds |
| `blackbox-http` | public HTTPS URLs | 60 seconds |
| `blackbox-local` | local OpenCloud, Keycloak, Grafana, Firecrawl, Hermes health URLs | 30 seconds |

Use Tailscale MagicDNS names only after verifying name resolution from the
Prometheus service sandbox. Otherwise declare stable Tailscale IPv4 addresses
in host configuration. Never use changing LAN DHCP addresses.

For workstation and Lenovo, use an absence grace period in alert rules. A
desktop sleeping overnight is not automatically critical, and Lenovo being
offline is normal. Their last-seen dashboards should still show the duration.

### Loki journal collection

Alloy runs as an unprivileged service account with membership only in the
groups required to read the system journal. It sends to HP's Loki endpoint over
Tailscale.

Keep these journal fields as bounded labels:

- host
- systemd unit
- priority
- transport

Collect warning-and-higher journal messages from every host plus complete logs
for a reviewed service allowlist on HP:

- `opencloud.service`
- `keycloak.service`
- `postgresql.service`
- `cloudflared-tunnel-d5383138-72c4-4879-924a-319edc4c20c6.service`
- `restic-backups-hp-offsite.service`
- `opencloud-identity-export.service`
- `syncthing-vault-backup.service`
- `syncthing-shared-backup.service`
- `github-mirror.service`
- `syncthing.service`
- `firecrawl.service`
- `hermes-agent.service`
- Prometheus, Alertmanager, Grafana, Loki, Alloy, and Blackbox Exporter units

If a named unit does not exist on the deployed host, record that as a dashboard
configuration issue rather than making Alloy fail. Apply redaction stages for
known authorization headers, bearer tokens, query-string secrets, and API-key
patterns before transmission. Validate redaction with synthetic secret-like
test messages.

## Dashboard Specification

Dashboards are version-controlled JSON generated or normalized so diffs remain
reviewable. Do not make the production Grafana database the canonical source.
Every dashboard includes a host selector, a time-range selector, links to the
corresponding logs, and a short panel description.

### 1. Fleet overview

The home dashboard answers “is everything okay?” at a glance:

- online/last-seen state for HP, workstation, and Lenovo
- firing warning and critical alerts
- CPU, memory, root-filesystem, load, and temperature summaries
- failed units by host
- current deployed NixOS generation age
- public probe state and TLS expiry for Cloud, Auth, and Monitor
- nightly Restic snapshot age and latest source health
- Syncthing Vault and Shared state
- HP uptime and last successful external heartbeat

Use traffic-light stat panels sparingly and make unknown/stale distinct from
healthy. An absent metric must never render as green.

### 2. HP services

- OpenCloud, Keycloak, PostgreSQL, Cloudflare Tunnel, Syncthing, Firecrawl,
  Hermes, backup exporters, and monitoring-stack unit state
- restart counts and recent failures
- service CPU and memory use
- local and external HTTP latency/status
- Cloudflare Tunnel connection health where its own metrics endpoint provides it
- relevant warning/error logs alongside metrics

### 3. Backup and synchronization

- latest Restic success, duration, bytes added, snapshot age, and repository
  check age
- staged-source health and freshness for OpenCloud state, identity export,
  Vault, Shared, GitHub mirrors, and Hermes
- GitHub mirror manifest freshness and repository count
- Syncthing pending items, error count, folder completion, and last scan
- links to `docs/BACKUP.md` and the recovery runbook

Hermes may initially appear degraded because the current implementation has no
reviewed native exporter. The dashboard must display that accurately instead of
masking it as an infrastructure failure.

### 4. Storage and hardware

- usage and predicted growth for `/`, `/nix/store`, `/srv/opencloud`, and
  monitoring data
- inode usage
- T7 mount presence and expected UUID
- SMART/NVMe health, temperature, reallocated/media errors, and wear indicators
- disk latency and throughput
- HP system temperature, throttling indicators, memory pressure, and OOM events
- Lenovo battery charge, design/full capacity, cycle count when available, and
  capacity trend
- top current and historical executable groups by CPU and resident memory;
  process CPU is expressed as percent of one core and may exceed 100%

SMART polling is observational. Do not schedule long tests or automatic repair
from this plan.

### 5. Logs

- warning/error rate by host and unit
- recent critical kernel and systemd events
- filtered views for Cloud/OpenCloud auth, backup, Syncthing, Firecrawl, Hermes,
  and the monitoring stack
- one-click correlation from an alert or metric panel to logs for the same host,
  unit, and time range

## Alert Policy

All alerts carry `severity`, `host`, `component`, `summary`, `description`, and
`runbook_url`. Alerts should describe impact and the first safe diagnostic
command. Use `for` durations to avoid transient noise.

### Host and storage alerts

| Alert | Warning | Critical |
| --- | --- | --- |
| HP exporter absent | 5 minutes | 15 minutes; external heartbeat also detects total outage |
| Workstation absent | informational after 3 days | warning after 14 days |
| Lenovo absent | informational after 14 days | warning after 30 days |
| Root/T7 filesystem usage | above 80% for 1 hour | above 90% for 15 minutes |
| Inode usage | above 80% for 1 hour | above 90% for 15 minutes |
| T7 mount | wrong/missing for 2 minutes | immediate critical if OpenCloud is active against the wrong filesystem |
| SMART/NVMe health | nonfatal media/wear warning | failing overall health or rising uncorrectable errors |
| Drive temperature | above device-specific warning for 15 minutes | above critical threshold for 5 minutes |
| Memory pressure | sustained PSI/swap pressure for 30 minutes | OOM event or repeated severe pressure |
| Nix store growth | exceeds agreed size for 24 hours | filesystem threshold takes precedence |
| NixOS generation age | older than 30 days | older than 60 days |
| Time synchronization | offset above 1 second for 10 minutes | offset above 5 seconds for 5 minutes |

### Service and public endpoint alerts

| Alert | Warning | Critical |
| --- | --- | --- |
| Important systemd unit failed | 10 minutes | immediate for OpenCloud, Keycloak, Cloudflare Tunnel, backup, or monitoring hub |
| OpenCloud public probe | 5 minutes | 15 minutes |
| Keycloak discovery/login endpoint | 5 minutes | 15 minutes |
| Grafana public probe | 10 minutes | rely on external heartbeat for total-stack failure |
| TLS certificate expiry | less than 21 days | less than 7 days |
| Cloudflare Tunnel connection | degraded for 10 minutes | no registered connection for 15 minutes |
| Firecrawl local health | 10 minutes | 30 minutes |
| Hermes process/health | 10 minutes | absent or restart-looping for 30 minutes |
| Loki/Prometheus/Alertmanager errors | sustained internal errors | unable to ingest/evaluate/send for 15 minutes |

Public probes must accept expected unauthenticated responses. For example,
OpenCloud APIs may correctly return `401`; probe a health or well-known endpoint
whose expected response is explicitly documented rather than treating every
non-`200` response as failure.

### Backup and synchronization alerts

| Alert | Warning | Critical |
| --- | --- | --- |
| Restic snapshot age | above 36 hours | above 72 hours |
| Repository check age | above 35 days | above 45 days |
| Any backup source degraded | one nightly cycle | two consecutive nightly cycles |
| OpenCloud state staging | missing/stale after nightly window | two missed cycles |
| Identity export | degraded/missing after nightly window | two missed cycles |
| GitHub mirror | degraded or stale above 36 hours | stale above 72 hours |
| Vault/Shared staging | degraded after nightly window | two missed cycles |
| Hermes export | degraded shown as warning until exporter exists | stale exporter after implementation is critical at 72 hours |
| Syncthing pending items | nonzero for 24 hours | rising/nonzero for 72 hours |

Suppress backup source alerts during the expected `03:00` backup consistency
window plus a conservative completion allowance. Do not suppress the external
backup heartbeat; it must become late when the complete workflow fails.

### Alertmanager routing

- group by `alertname`, `host`, and `component`
- wait 30 seconds before the first grouped notification
- repeat critical alerts every 4 hours and warnings every 12 hours while active
- send resolved notifications
- inhibit warning alerts when a critical alert for the same host/component is
  firing
- inhibit dependent service alerts when HP itself is confirmed down
- never inhibit the independent dead-man notification

## Implementation Phases

Each phase must be independently buildable, deployable, testable, and
reversible. Inspect the dirty worktree before editing, preserve unrelated work,
and do not commit unless explicitly requested.

### Phase 1: Define contracts and replace the unsafe legacy module

Objective: establish module boundaries, metric names, directories, and tests
before deploying listeners.

Files:

- remove or replace `modules/features/network/server-monitoring.nix`
- add `modules/features/monitoring/exporter.nix`
- add `modules/features/monitoring/hub.nix`
- add metric scripts and fixture-based tests
- update flake module exports

Actions:

1. Capture the current port inventory and service baseline on all hosts.
2. Add module options and assertions with `enable = false` defaults.
3. Implement atomic textfile helpers and fixture tests for healthy, degraded,
   stale, missing, and malformed status JSON.
4. Ensure generated `.prom` files pass `promtool check metrics` or an equivalent
   parser check.
5. Delete the hardcoded Grafana password and global monitoring firewall ports.
6. Add evaluation checks proving disabled modules create no listeners or users.

Acceptance:

- repository search finds no `StrongPassword123`
- module evaluation succeeds on all three hosts while monitoring is disabled
- malformed status input cannot leave a stale healthy metric
- no new port is globally allowed

Rollback: remove the new imports/options. No runtime state exists yet.

### Phase 2: Deploy exporters and journal agents over Tailscale

Objective: collect host metrics and selected logs without exposing them to LAN
or internet.

Files:

- `modules/features/monitoring/exporter.nix`
- `modules/features/monitoring/alloy/journal.alloy`
- all three host configurations

Actions:

1. Enable the exporter module on HP first.
2. Confirm collectors and metric script output locally.
3. Enable it on workstation, then Lenovo.
4. Restrict exporter and Loki-ingestion traffic to `tailscale0`.
5. Add battery collection only on Lenovo and SMART collection only for devices
   present on each host.
6. Start Alloy with journal access and verify it has no home/secret access.
7. Confirm services remain healthy when HP or Tailscale is temporarily absent;
   buffering must be bounded.

Verification:

```bash
systemctl --no-pager --full status prometheus-node-exporter alloy
sudo ss -lntup
curl -fsS http://127.0.0.1:9100/metrics | head
tailscale status
```

From HP, test each Tailscale target. From a LAN-only machine, confirm exporter
ports are unreachable.

Acceptance:

- each online host exposes Node Exporter only through the intended boundary
- host metric files parse and update on schedule
- Lenovo battery metrics exist without errors on AC or battery power
- Alloy does not leak a synthetic bearer token into received logs
- workstation and Lenovo continue normally while HP is offline

Rollback: disable exporter imports host by host and rebuild. Remove no journal
data manually.

### Phase 3: Deploy the private HP monitoring hub

Objective: build a complete local monitoring stack before public ingress.

Files:

- `modules/features/monitoring/hub.nix`
- Prometheus rules
- Alloy/Loki configuration
- HP host configuration
- `secrets/monitoring.yaml` and `.sops.yaml`

Actions:

1. Add the monitoring SOPS creation rule for personal recipients and HP.
2. Configure Prometheus retention, scrape jobs, rules, and self-monitoring.
3. Configure Alertmanager with a temporary local/null receiver until Phase 4.
4. Configure monolithic Loki and bounded retention.
5. Configure Grafana on loopback with anonymous access disabled.
6. Provision Prometheus and Loki data sources.
7. Configure Blackbox Exporter for public and loopback HTTP probes.
8. Configure bounded persistent journald.
9. Verify configuration with `promtool`, `amtool`, Grafana provisioning logs,
   Loki readiness, and NixOS builds.

Verification:

```bash
sudo nixos-rebuild dry-activate --flake .#hp-server
sudo nixos-rebuild switch --flake .#hp-server
systemctl --no-pager --full status prometheus alertmanager grafana loki prometheus-blackbox-exporter
curl -fsS http://127.0.0.1:9090/-/ready
curl -fsS http://127.0.0.1:9093/-/ready
curl -fsS http://127.0.0.1:3100/ready
curl -fsS http://127.0.0.1:3000/api/health
sudo ss -lntup
```

Acceptance:

- all online hosts appear as healthy targets in Prometheus
- no backend port is reachable from public or LAN interfaces
- Grafana is reachable only on HP loopback before tunnel setup
- Loki contains redacted test journal events from all online hosts
- storage growth is bounded and its own filesystem is monitored

Rollback: disable `my.monitoring.hub.enable`, rebuild HP, and retain state for a
later retry. Do not delete monitoring data as part of rollback.

### Phase 4: Add notification delivery and external dead-man monitoring

Objective: prove alerts reach the user even when HP is unavailable.

Files:

- `secrets/monitoring.yaml`
- Alertmanager receiver template/configuration
- heartbeat service and timers
- alert runbook

Actions:

1. Create the dedicated Telegram notification receiver and two external
   heartbeat checks.
2. Encrypt all tokens, recipient IDs, and heartbeat URLs with SOPS.
3. Render root-only runtime credentials.
4. Configure Alertmanager grouping, inhibition, repeats, and resolved messages.
5. Send the stack heartbeat only after Prometheus, Alertmanager, Loki, and
   Grafana local health checks succeed.
6. Send the backup heartbeat only from the successful end of the nightly Restic
   workflow, after source checks and snapshot publication.
7. Deliberately trigger and resolve a test alert.
8. Withhold each heartbeat long enough to receive the external notification.

Acceptance:

- warning, critical, and resolved notifications render host/component/runbook
- a stopped exporter creates exactly one actionable grouped incident
- disabling the HP heartbeat produces an external notification
- a failed backup cannot send the backup-success heartbeat
- no receiver secret appears in `/nix/store`, process arguments, or logs

Rollback: disable heartbeat timers and switch Alertmanager to the local/null
receiver. Keep external checks paused rather than deleting them immediately.

### Phase 5: Publish Grafana through Cloudflare and configure Keycloak SSO

Objective: make the dashboard safely available from any browser at
`monitor.henhal.net`.

Files:

- `modules/features/network/cloudflare-tunnel.nix`
- `modules/features/monitoring/hub.nix`
- `secrets/monitoring.yaml`
- HP host configuration

One-time Keycloak actions:

1. Create the `monitoring` realm.
2. Require `Configure OTP` and recovery authentication codes.
3. Create realm roles `grafana-admin`, `grafana-editor`, and `grafana-viewer`.
4. Create confidential client `grafana` with standard authorization code flow.
   Enable PKCE with `S256` if supported for the selected confidential-client
   configuration.
5. Set valid redirect URI to
   `https://monitor.henhal.net/login/generic_oauth`.
6. Set valid post-logout redirect URI to `https://monitor.henhal.net/*`.
7. Set web origin to `https://monitor.henhal.net`.
8. Add role/group claims required by Grafana role mapping.
9. Assign the routine account and break-glass account deliberately; do not use
   realm-wide default admin privileges.
10. Encrypt the client secret in `secrets/monitoring.yaml`.

One-time Cloudflare actions:

1. Add the tunnel DNS route:

   ```bash
   cloudflared tunnel route dns hp-opencloud monitor.henhal.net
   ```

2. Add a cache rule that bypasses cache for `monitor.henhal.net`.
3. Keep proxying enabled and do not create a router port-forward.

Deployment actions:

1. Configure Grafana Generic OAuth and strict role mapping.
2. Verify OAuth locally using a temporary hosts override or a controlled tunnel
   route before broad use.
3. Add the Grafana ingress to the existing declarative tunnel map.
4. Rebuild HP and confirm the catch-all still returns `404` for unknown hosts.
5. Test login, logout, MFA, Viewer access, Admin access, and denial for an
   unassigned user.

Acceptance:

- `https://monitor.henhal.net` is usable from a machine outside the home network
- anonymous users cannot see Grafana, metrics, logs, or API data
- Keycloak MFA is required according to the realm policy
- Viewer cannot edit dashboards or data sources
- only explicit admin role membership grants Grafana Admin
- Prometheus, Alertmanager, Loki, and exporter URLs remain unreachable publicly
- Cloudflare Tunnel still serves OpenCloud and Keycloak correctly

Rollback: remove the `monitor.henhal.net` DNS route and tunnel ingress first,
then disable Grafana OAuth if local recovery is required. Existing Cloud and Auth
routes remain untouched.

### Phase 6: Build and provision the custom dashboards

Objective: provide the five dashboards specified above with meaningful unknown,
warning, and critical states.

Files:

- `modules/features/monitoring/dashboards/*.json`
- Grafana provisioning configuration
- dashboard screenshot/JSON validation fixtures where useful

Actions:

1. Build the Fleet Overview first using only validated metric contracts.
2. Add HP Services with metric-to-log links.
3. Add Backup and Synchronization using the staged source metrics.
4. Add Storage and Hardware.
5. Add Logs and investigation links.
6. Assign stable dashboard UIDs and folders.
7. Disable UI save for provisioned dashboards or document that UI edits are
   temporary and must be exported back to Git deliberately.
8. Test panels with live, absent, stale, degraded, and critical fixture states.

Acceptance:

- Fleet Overview answers overall health without opening other dashboards
- missing data is gray/unknown, never green
- all important panels link to relevant logs or the correct runbook
- all dashboards survive Grafana state-directory recreation from provisioning
- no dashboard contains a secret, private URL token, or hardcoded transient IP

Rollback: revert dashboard provisioning files. Backend collection continues.

### Phase 7: Enable production alert rules and service-specific coverage

Objective: activate actionable alerting after baseline behavior is known.

Files:

- `modules/features/monitoring/rules/*.yaml`
- service metric collectors
- `docs/runbooks/monitoring-alerts.md`

Actions:

1. Observe seven days of baseline metrics before enabling noisy resource alerts.
2. Enable hard availability, disk, mount, SMART, backup, and TLS alerts first.
3. Add CPU, memory, temperature, and backlog alerts using observed baselines.
4. Add OpenCloud, Keycloak, Cloudflare Tunnel, Firecrawl, Hermes, Syncthing, and
   GitHub mirror coverage.
5. Add Lenovo-specific long absence and battery-health rules.
6. Run one controlled failure test per alert family.
7. Record false positives and tune expressions/durations rather than adding
   broad silences.

Acceptance:

- every production alert has a tested triggering condition and runbook entry
- expected nightly backup downtime does not page for OpenCloud transiently
- workstation sleep and Lenovo travel do not create repeated critical alerts
- HP outage and failed nightly backup remain independently detectable
- notification volume is low enough that a real critical alert remains visible

Rollback: disable the affected rule group, not the entire monitoring stack.

### Phase 8: Documentation, recovery, and final validation

Objective: make monitoring understandable and recoverable without prior memory.

Files:

- `docs/MONITORING.md`
- `docs/runbooks/monitoring-alerts.md`
- `docs/runbooks/monitoring-recovery.md`
- `docs/HOSTS.md`
- `docs/FEATURES.md`
- `docs/SECRETS.md`

Document:

- architecture, ports, data flow, storage, and retention
- login, role management, and break-glass access
- how to add a host, service probe, dashboard panel, and alert
- how to inspect Prometheus targets, active alerts, Loki logs, and Alertmanager
- notification and heartbeat credential rotation
- dashboard update/export workflow
- monitoring recovery after HP rebuild
- what the system cannot detect when HP is down
- quarterly alert and recovery test procedure

Final validation:

1. Build all three hosts:

   ```bash
   nix build .#nixosConfigurations.hp-server.config.system.build.toplevel
   nix build .#nixosConfigurations.workstation.config.system.build.toplevel
   nix build .#nixosConfigurations.lenovo-yoga-pro-7.config.system.build.toplevel
   ```

2. Test an exporter outage and recovery.
3. Test OpenCloud and Keycloak public-probe failures without breaking stored data.
4. Test a synthetic disk-space alert using a test metric, not by filling a disk.
5. Test backup-source degradation using fixtures or a dedicated test metric.
6. Test one redacted log event from each host.
7. Stop the heartbeat sender and receive the external notification.
8. Recreate a disposable Grafana state directory and confirm dashboards/data
   sources return from provisioning.
9. Verify public and local port boundaries from outside the home network.
10. Confirm the existing OpenCloud login, desktop sync, mobile upload, nightly
    Restic backup, and GitHub mirror workflows still operate.

Acceptance:

- all tests above pass and are recorded in a completion note
- a fresh operator can determine why an alert fired using the linked runbook
- monitoring configuration is reproducible from Git and SOPS
- complete loss of monitoring data does not prevent OpenCloud or backup recovery

## Recovery Plan

Monitoring is intentionally recoverable rather than backed up as irreplaceable
state.

After rebuilding HP:

1. Restore or check out this repository.
2. Restore access to the personal/HP SOPS recipients.
3. Rebuild HP with the monitoring hub and existing tunnel credential.
4. Confirm Tailscale identity and exporter reachability.
5. Recreate Prometheus and Loki empty state directories if necessary.
6. Let Grafana provision data sources and dashboards from Git.
7. Confirm the Keycloak `monitoring` realm/client survived through the existing
   identity backup; otherwise recreate it from the documented values and rotate
   the client secret.
8. Confirm the Cloudflare DNS route still targets the existing tunnel.
9. Resume external heartbeat checks only after local health tests pass.
10. Re-run the Phase 8 validation tests.

Historical metrics and logs may be lost in a total HP-system-disk loss. That is
acceptable because they are diagnostic history, while dashboard definitions,
alert rules, and collector logic live in Git. If historical monitoring data is
later judged irreplaceable, add a separate reviewed backup source rather than
silently including live Prometheus/Loki state in Restic.

## Operational Schedule

| Task | Schedule |
| --- | --- |
| Node Exporter scrape | every 30 seconds while host is online |
| Public HTTP/TLS probes | every 60 seconds |
| Textfile metric refresh | every 5 minutes unless event-driven |
| Backup metrics | after nightly backup plus periodic freshness calculation |
| SMART/NVMe summary | every 15 minutes |
| Nix/store and generation metrics | every 6 hours |
| Monitoring-stack dead-man heartbeat | every 5 minutes |
| Backup-success dead-man heartbeat | once after the successful nightly run |
| Alert-rule/configuration test | on every relevant build/change |
| Manual dashboard and alert review | monthly |
| Controlled alert delivery test | quarterly |
| Monitoring recovery/provisioning drill | annually and after major upgrades |

Randomize nonurgent collectors slightly so they do not all wake machines or hit
storage at the same second. Do not wake the Lenovo solely for monitoring.

## Definition of Done

- [x] The unsafe legacy monitoring module is gone.
- [x] All three configured hosts provide metrics over Tailscale only when online.
- [x] Selected journals arrive in Loki with bounded labels and redaction.
- [x] HP runs healthy Prometheus, Alertmanager, Grafana, Loki, and Blackbox
      Exporter services with bounded storage.
- [x] `monitor.henhal.net` routes only to loopback Grafana through the existing
      Cloudflare Tunnel.
- [x] Grafana requires Keycloak OIDC, MFA, and explicit role mapping.
- [x] Prometheus, Alertmanager, Loki, and exporter endpoints are not public.
- [x] The five custom dashboards are provisioned from Git and render unknown
      data safely.
- [x] Backup, OpenCloud, Keycloak, Cloudflare Tunnel, Syncthing, GitHub mirror,
      Firecrawl, Hermes, storage, systemd, NixOS, and Lenovo battery state are
      visible.
- [x] Warning, critical, resolved, inhibition, and grouping behavior is configured;
      firing and resolved Telegram delivery was tested.
- [x] HP and nightly backup dead-man checks notify independently.
- [x] Expected laptop absence and the nightly backup window do not cause alert
      fatigue.
- [x] Documentation and recovery procedures are complete; recurring drills remain
      an operational schedule item.
- [x] All three host configurations build successfully.
- [x] Existing Cloud, Auth, synchronization, and R2 backup behavior remains
      healthy after deployment.

## Explicitly Out of Scope

- automatic service repair, reboot, rollback, or NixOS deployment
- automatic SMART repair or filesystem repair
- firmware updates, kernel tuning, partitioning, hibernation, or storage changes
- Restic retention deletion, R2 lifecycle deletion, or repository pruning
- public Prometheus, Alertmanager, Loki, exporter, or Alloy endpoints
- application performance tracing and distributed tracing
- monitoring Android phones or unrelated devices
- backing up live Prometheus or Loki databases
- replacing Keycloak, Cloudflare Tunnel, Tailscale, or the completed backup stack

## References

- [Prometheus security model](https://prometheus.io/docs/operating/security/)
- [Grafana authentication documentation](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/)
- [Grafana provisioning documentation](https://grafana.com/docs/grafana/latest/administration/provisioning/)
- [Grafana Alloy systemd journal source](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.journal/)
- [Grafana Loki documentation](https://grafana.com/docs/loki/latest/)
- [Cloudflare Tunnel configuration](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/)
- [NixOS Prometheus options](https://search.nixos.org/options?query=services.prometheus)
- [NixOS Grafana options](https://search.nixos.org/options?query=services.grafana)
- [NixOS Loki options](https://search.nixos.org/options?query=services.loki)
