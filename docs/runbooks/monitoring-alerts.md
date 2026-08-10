# Monitoring Alert Runbook

## First response

1. Read the alert's host, component, severity, age, and description.
2. Determine whether the problem is still firing or has already resolved.
3. Open the linked Grafana dashboard and correlate metrics with logs.
4. Run read-only diagnostics before restarting or changing anything.
5. Treat simultaneous HP-host, tunnel, and service alerts as one likely HP,
   power, or network incident rather than separate failures.

Useful commands on HP:

```bash
systemctl --failed --no-pager
systemctl --no-pager --full status <unit>
sudo journalctl -u <unit> --since '2 hours ago' --no-pager
df -h
df -i
findmnt /srv/opencloud
tailscale status
```

## HP server or monitoring hub unavailable

- Check power, home internet, router, and Tailscale reachability from outside.
- If SSH works, inspect `prometheus`, `alertmanager`, `grafana`, `loki`,
  `cloudflared`, and the heartbeat timer/service.
- Do not resolve the external incident merely because the local dashboard is
  inaccessible; the external heartbeat is the authoritative outside signal.

## Remote host offline

Workstation and Lenovo are allowed to be offline. Confirm whether the machine is
expected to be powered on before treating the alert as an incident. When it is
online, check Tailscale, `prometheus-node-exporter`, and
`prometheus-process-exporter`; do not wake Lenovo solely for monitoring.

## Public Cloud/Auth/Monitor probe failed

Check the local origin before Cloudflare:

```bash
curl -fsS http://127.0.0.1:3000/api/health
curl -fsS http://127.0.0.1:8080/realms/opencloud/.well-known/openid-configuration
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9200/
systemctl --no-pager --full status \
  cloudflared-tunnel-d5383138-72c4-4879-924a-319edc4c20c6.service
```

If local origins work, inspect Cloudflare Tunnel logs, DNS, and Cloudflare
status. If they do not, inspect the owning service. Avoid restarting OpenCloud
during the expected nightly consistency window unless it failed to return.

## Public endpoint unavailable

Use the same origin-first checks above. A successful local origin with a failed
public probe points toward Cloudflare Tunnel, DNS, certificate, or upstream
connectivity rather than the application itself.

## TLS certificate expiry

Inspect the certificate served publicly before changing Keycloak, Grafana, or
OpenCloud. Confirm Cloudflare's edge certificate state and the affected hostname;
do not install a public certificate on the loopback-only origin as a shortcut.

## Backup stale or source degraded

```bash
systemctl --no-pager --full status restic-backups-hp-offsite.service
sudo journalctl -u restic-backups-hp-offsite.service --since '2 days ago' --no-pager
sudo restic-hp-offsite snapshots --latest 3

sudo jq -s . \
  /var/lib/restic-status/opencloud-source.json \
  /var/lib/restic-status/opencloud-identity.json \
  /var/lib/restic-status/vault.json \
  /var/lib/restic-status/shared.json \
  /var/lib/restic-status/radicale.json \
  /var/lib/restic-status/hermes.json \
  /var/lib/github-mirrors/status.json
```

Do not run `forget`, `prune`, or R2 deletion to fix a freshness alert. Diagnose
the failed source or backup and preserve the last good snapshot.

Hermes remains degraded until a reviewed native export command is configured;
this is a known source-level warning, not evidence that all backups failed.

For a Radicale source alert, inspect both the staging unit and the service:

```bash
systemctl --no-pager --full status radicale.service radicale-backup-stage.service
sudo journalctl -u radicale.service -u radicale-backup-stage.service \
  --since '2 days ago' --no-pager
sudo jq . /var/lib/restic-status/radicale.json
findmnt /srv/opencloud
```

Do not point Restic at the live collection directory to bypass a failed stage.
Confirm the T7 mount, service ownership, and Radicale storage verification;
the previous validated stage should remain available while the source reports
degraded.

## Filesystem capacity

```bash
df -h
df -i
```

Identify growth before deleting anything. Do not run Nix garbage collection,
Restic pruning, or application-data deletion merely to clear the alert.

## T7 OpenCloud mount

```bash
df -h
df -i
findmnt /srv/opencloud
lsblk -f
sudo smartctl -x /dev/sda
sudo journalctl -k --since '24 hours ago' --no-pager
```

If `/srv/opencloud` is missing or has the wrong UUID, stop OpenCloud before it
writes to the underlying mountpoint directory. Do not run filesystem repair,
SMART long tests, firmware updates, or destructive cleanup without a separate
review.

## Disk health

Use `lsblk`, `smartctl`, and kernel logs from the T7 section above. Preserve a
current backup before any separately reviewed repair or replacement work.

## Stale NixOS generation

Compare `/run/current-system` with the intended flake revision and recent build
history. Rebuild through the normal host workflow; do not upgrade unrelated
inputs merely to make the age metric newer.

## Syncthing backlog

Open the Syncthing UI through its existing private access path and identify the
folder/device. Check free space, scan errors, permission errors, and conflicts.
Do not delete conflict files until their contents have been reviewed.

## Systemd unit failed

```bash
systemctl show <unit> -p ActiveState -p SubState -p Result -p NRestarts
sudo journalctl -u <unit> -b --no-pager
```

Check credentials, mounts, dependencies, and port conflicts before restarting.
Use `systemctl reset-failed` only after understanding the failure.

## Failed service or restart loop

Follow the systemd-unit procedure above. This heading is retained for alerts
that use the combined runbook anchor.

## Service health probe

Run the exact loopback health endpoint shown by the alert, then inspect the
owning unit. If the local endpoint succeeds but the public probe fails, move to
the public-endpoint procedure instead of restarting the service.

## Service restart loop

Inspect `NRestarts` and the current-boot journal as shown above. Find the first
failure in the loop; later messages are often only consequences.

## Monitoring collector failed

```bash
grep -R 'henhal_metric_collector_error.* 1' \
  /var/lib/prometheus-node-exporter-text-files
sudo journalctl -u 'henhal-monitoring-*' --since '2 hours ago' --no-pager
```

Treat missing or malformed source state as unknown/degraded. Do not replace a
failed collector output with a manually written healthy metric.

## Memory pressure

Use Fleet overview to identify the host and time window, then open **Storage and
hardware**. Its process panels show top executable groups by CPU and resident
memory. CPU is percent of one core and may exceed 100%. For a host shell check:

```bash
ps -eo pid,comm,%cpu,%mem,rss --sort=-rss | head -20
```

Do not kill a process based only on one sample; correlate the timeline with its
service journal and workload.

## Nix store growth

This alert is currently visible but notification-suppressed while storage work
is deferred. Inspect with `nix path-info`, `nix-store --query --roots`, and
`du` before proposing garbage collection. Do not delete store paths manually.

## Notification behavior

Telegram receives grouped firing and resolved notifications. The initial group
wait is 30 seconds; critical alerts repeat every 4 hours and warnings every 12
hours while still active. Critical alerts inhibit matching warnings.

Hermes `BackupSourceDegraded`/`BackupSourceStillDegraded` and `NixStoreLarge`
route to `local-null` until their explicitly deferred implementation/capacity
work is resumed. They remain visible in Prometheus and Grafana.

## Alert testing

Quarterly, test:

- one synthetic warning and critical alert
- exporter stop/recovery on a noncritical host
- notification grouping and resolved delivery
- both external dead-man checks by withholding heartbeats
- a synthetic backup-age/source-degraded metric
- log redaction using a fake token, never a real credential

Record the date, result, and any threshold changes.
