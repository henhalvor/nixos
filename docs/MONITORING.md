# Monitoring

## Overview

`hp-server` is the monitoring hub for the three NixOS systems. Prometheus
collects metrics, Loki stores selected systemd journal logs, Alertmanager sends
notifications, and Grafana presents provisioned dashboards. The only public
component is Grafana at `https://monitor.henhal.net`; it is reached through the
existing outbound Cloudflare Tunnel and authenticated by Keycloak.

Prometheus, Alertmanager, Loki, Node Exporter, Alloy, and Blackbox Exporter are
not public services. Cross-machine telemetry uses Tailscale.

The canonical implementation design is
[security-monitoring-implementation.md](plans/security-monitoring-implementation.md).

## What is monitored

- CPU, load, memory pressure, network, filesystem, inode, and disk activity
- systemd failures, restarts, uptime, time synchronization, and NixOS age
- SMART/NVMe health and disk temperature
- Lenovo battery capacity and charge state
- public availability and TLS expiry for Cloud, Auth, and Monitor
- OpenCloud, Keycloak, PostgreSQL, Cloudflare Tunnel, Firecrawl, Hermes, and
  the monitoring stack itself
- Restic snapshot freshness, sampled repository checks, and every staged source
- Syncthing Vault/Shared health and GitHub mirror freshness
- selected warning/error journal events with bounded labels and redaction

The laptop and workstation are allowed to be offline. Their dashboards retain
last-seen state and alerts use long grace periods. HP and the nightly backup
have independent external dead-man heartbeats because HP cannot report its own
power or internet outage.

## Access

The first rebuild intentionally starts the monitoring hub privately. Grafana
has no initial local administrator, OIDC is disabled, notifications and
heartbeats are disabled, and no `monitor.henhal.net` tunnel route is declared.
This prevents a partially configured dashboard from becoming public.

After completing the activation procedure below, open
`https://monitor.henhal.net` and sign in through the Keycloak `monitoring`
realm. Routine users should be Grafana Viewers. Only explicitly assigned
`grafana-admin` users receive administrator access.

Backends remain local/private:

| Component | HP endpoint | Exposure |
| --- | --- | --- |
| Grafana | `127.0.0.1:3000` | Cloudflare Tunnel only |
| Prometheus | `127.0.0.1:9090` | loopback |
| Alertmanager | `127.0.0.1:9093` | loopback |
| Loki query/readiness | `127.0.0.1:3100` | loopback |
| Node Exporter | port `9300` | loopback/Tailscale firewall |
| Blackbox Exporter | `127.0.0.1:9315` | Prometheus only |

## Complete the external activation

These steps require provider credentials and therefore cannot be represented by
placeholder values in the repository.

### 1. Create monitoring secrets

Create `secrets/monitoring.yaml` with SOPS. The creation rule is already in
`.sops.yaml` and grants access to the personal recipients and HP only.

```yaml
GRAFANA_OAUTH_CLIENT_SECRET: <Keycloak confidential-client secret>
GRAFANA_ADMIN_PASSWORD: <random break-glass password>
GRAFANA_SECRET_KEY: <at least 32 random bytes encoded as text>
MONITORING_TELEGRAM_BOT_TOKEN: <dedicated bot token>
MONITORING_TELEGRAM_CHAT_ID: <numeric chat ID>
MONITORING_STACK_HEARTBEAT_URL: <independent HTTPS heartbeat URL>
MONITORING_BACKUP_HEARTBEAT_URL: <different independent HTTPS heartbeat URL>
```

Do not commit plaintext or substitute fake encrypted values.

### 2. Create the Keycloak realm and client

In Keycloak:

1. Create realm `monitoring`.
2. Require Configure OTP and recovery authentication codes.
3. Create realm roles `grafana-admin` and `grafana-viewer`.
4. Create confidential client `grafana` with authorization-code flow and PKCE
   `S256`.
5. Set the redirect URI exactly to
   `https://monitor.henhal.net/login/generic_oauth`.
6. Set the post-logout URI to `https://monitor.henhal.net/*` and web origin to
   `https://monitor.henhal.net`.
7. Ensure realm roles appear in the access token as `realm_access.roles`.
8. Assign one routine admin, one Viewer test user, and one break-glass admin.

### 3. Enable secrets, OIDC, notifications, and heartbeats

Change the HP hub block to include:

```nix
my.monitoring.hub = {
  enable = true;
  enableOidc = true;
  enableNotifications = true;
  enableHeartbeats = true;
  secretFile = ../../secrets/monitoring.yaml;
  # Keep the existing lokiPushListenAddress and scrapeTargets.
};
```

Add the Grafana origin to the existing tunnel declaration:

```nix
my.opencloudTunnel.extraIngress."monitor.henhal.net" = {
  service = "http://127.0.0.1:3000";
  httpHostHeader = "monitor.henhal.net";
};
```

Then build, switch, and verify locally before creating public DNS.

### 4. Create Cloudflare DNS and cache rules

From a machine holding the Cloudflare origin certificate:

```bash
cloudflared tunnel route dns hp-opencloud monitor.henhal.net
```

Add a Cloudflare cache-bypass rule for `monitor.henhal.net`. Do not create a
router port-forward and do not add Prometheus, Alertmanager, Loki, or exporter
hostnames.

### 5. Test the boundaries

- login requires Keycloak and MFA
- a Viewer cannot edit dashboards or data sources
- an unassigned Keycloak user is denied by strict role mapping
- local break-glass login works and its password remains offline
- Telegram receives firing and resolved test alerts
- withholding each heartbeat triggers its external late notification
- public requests to backend ports fail

## Routine checks

On HP:

```bash
systemctl --no-pager --full status \
  prometheus alertmanager grafana loki alloy prometheus-node-exporter

curl -fsS http://127.0.0.1:9090/-/ready
curl -fsS http://127.0.0.1:9093/-/ready
curl -fsS http://127.0.0.1:3100/ready
curl -fsS http://127.0.0.1:3000/api/health

sudo ss -lntup
```

Inspect Prometheus targets:

```bash
curl -fsS http://127.0.0.1:9090/api/v1/targets \
  | jq -r '.data.activeTargets[] | [.labels.job, .labels.instance, .health, (.lastError // "")] | @tsv'
```

Inspect active alerts:

```bash
curl -fsS http://127.0.0.1:9090/api/v1/alerts \
  | jq '.data.alerts[] | {state, labels, annotations}'
```

Inspect recent monitoring logs:

```bash
sudo journalctl -u prometheus -u alertmanager -u grafana -u loki -u alloy \
  --since '1 hour ago' --no-pager
```

## Adding a monitored host

1. Import `self.nixosModules.monitoringExporter` in the host.
2. Enable `my.monitoring.exporter` and set the HP tailnet destination.
3. Add only the necessary exporter/log-ingestion port to `tailscale0`.
4. Add its stable MagicDNS name to `my.monitoring.hub.scrapeTargets` on HP.
5. Rebuild the client first, then HP.
6. Confirm the target is `UP`, logs arrive, and LAN/public access fails.
7. Add absence thresholds appropriate to the host's expected availability.

Do not use a changing LAN DHCP address and do not open exporter ports globally.

## Adding a service or alert

1. Prefer an existing service metric or a safe HTTP health endpoint.
2. If a custom collector is necessary, publish atomic Prometheus textfiles with
   the `henhal_` prefix and no secrets or unbounded labels.
3. Add a dashboard panel with an unknown/no-data state distinct from healthy.
4. Add a rule with a `for` duration, severity, impact, diagnostic hint, and
   runbook link.
5. Validate with `promtool check rules` and a synthetic test condition.
6. Verify warning, critical, resolution, grouping, and inhibition behavior.

Never test disk alerts by filling a real filesystem. Use a temporary synthetic
metric or rule expression.

## Data retention and backup boundary

Prometheus metrics and Loki logs are bounded operational history stored on HP's
system disk. They are intentionally not included in the R2 Restic backup.
Dashboards, alert rules, collectors, and provisioning live in Git, so the stack
can be recreated after loss. Keycloak realm/client data is covered by the
existing identity export.

See [monitoring-recovery.md](runbooks/monitoring-recovery.md) for rebuilding the
stack and [monitoring-alerts.md](runbooks/monitoring-alerts.md) for incident
handling.
