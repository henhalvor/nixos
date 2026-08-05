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

## HP or monitoring heartbeat missing

- Check power, home internet, router, and Tailscale reachability from outside.
- If SSH works, inspect `prometheus`, `alertmanager`, `grafana`, `loki`,
  `cloudflared`, and the heartbeat timer/service.
- Do not resolve the external incident merely because the local dashboard is
  inaccessible; the external heartbeat is the authoritative outside signal.

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
  /var/lib/restic-status/hermes.json \
  /var/lib/github-mirrors/status.json
```

Do not run `forget`, `prune`, or R2 deletion to fix a freshness alert. Diagnose
the failed source or backup and preserve the last good snapshot.

Hermes remains degraded until a reviewed native export command is configured;
this is a known source-level warning, not evidence that all backups failed.

## Disk, mount, or SMART alert

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

## Syncthing backlog

Open the Syncthing UI through its existing private access path and identify the
folder/device. Check free space, scan errors, permission errors, and conflicts.
Do not delete conflict files until their contents have been reviewed.

## Failed service or restart loop

```bash
systemctl show <unit> -p ActiveState -p SubState -p Result -p NRestarts
sudo journalctl -u <unit> -b --no-pager
```

Check credentials, mounts, dependencies, and port conflicts before restarting.
Use `systemctl reset-failed` only after understanding the failure.

## Alert testing

Quarterly, test:

- one synthetic warning and critical alert
- exporter stop/recovery on a noncritical host
- notification grouping and resolved delivery
- both external dead-man checks by withholding heartbeats
- a synthetic backup-age/source-degraded metric
- log redaction using a fake token, never a real credential

Record the date, result, and any threshold changes.

