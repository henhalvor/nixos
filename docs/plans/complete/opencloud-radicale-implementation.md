# OpenCloud calendar and contacts implementation plan

## Goal

Self-host personal calendars, tasks, and contacts on the HP server, access them
from phones and other CalDAV/CardDAV clients through the existing
`https://cloud.henhal.net` endpoint, and protect the server-side data in the
existing encrypted Restic repository in Cloudflare R2.

The result must preserve the current trust boundaries:

- OpenCloud remains the only public application endpoint.
- Keycloak remains the sole interactive identity provider and MFA authority.
- Radicale listens only on HP loopback and trusts identity headers only from
  OpenCloud's authenticated proxy.
- Radicale data lives on the mounted Samsung T7, but outside OpenCloud's own
  state directory.
- Restic remains the only R2 client. R2 is not mounted or exposed to DAV
  clients.
- A Radicale backup is considered healthy only after a consistent, validated
  staging operation.

This document is an implementation plan only. It does not change the running
system.

## Implementation status

The declarative service, authenticated OpenCloud routes, validated Restic
source, monitoring integration, and operations documentation were implemented
and the complete HP system closure built successfully on 2026-08-10. Remote
activation, live DAV identity/client tests, the first healthy Radicale staging
run, the first R2 snapshot containing that stage, and the isolated restore
rehearsal remain runtime acceptance gates.

## Source material and current baseline

Implementation should be checked against these sources at the time it begins:

- [OpenCloud Radicale integration guide](https://docs.opencloud.eu/docs/admin/configuration/radicale-integration/)
- [OpenCloud Compose proxy routes](https://github.com/opencloud-eu/opencloud-compose/blob/main/config/opencloud/proxy.yaml)
- [OpenCloud Compose Radicale configuration](https://github.com/opencloud-eu/opencloud-compose/blob/main/config/radicale/config)
- [NixOS OpenCloud Radicale example](https://wiki.nixos.org/wiki/OpenCloud#Radicale)
- [Radicale v3 documentation](https://radicale.org/v3.html)

As evaluated from the current flake on 2026-08-10:

- OpenCloud is version `7.3.0`, above the integration guide's minimum of
  `2.3.0`.
- NixOS provides Radicale `3.5.8` through `services.radicale`.
- OpenCloud listens on `127.0.0.1:9200` and is published as
  `https://cloud.henhal.net` through the existing Cloudflare Tunnel.
- Keycloak listens on `127.0.0.1:8080` and is published as
  `https://auth.henhal.net`.
- OpenCloud uses Keycloak OIDC, app-token support, and automatic account
  provisioning into its loopback-only OpenLDAP directory.
- OpenCloud state is stored at `/srv/opencloud/state` on the UUID-verified T7.
- The nightly 03:00 Restic job stages or exports required application sources,
  then writes encrypted snapshots to the private R2 repository.
- Monitoring already reports systemd state, local/public availability, Restic
  freshness, and per-source backup health.

OpenCloud does not currently provide a calendar or contacts web UI. It supplies
authentication, app tokens, discovery endpoints, and proxying; a phone or
desktop DAV client supplies the user interface.

## Target architecture

```text
Phone or desktop DAV client
  |  HTTPS, OpenCloud username + per-device app token
  v
cloud.henhal.net
  |  existing Cloudflare Tunnel
  v
OpenCloud proxy on 127.0.0.1:9200
  |  authenticated request + X-Remote-User
  |  /caldav/, /carddav/, /.well-known/caldav, /.well-known/carddav
  v
Radicale on 127.0.0.1:5232
  |
  v
/srv/opencloud/radicale/collections on the T7
  |
  |  stopped-service validation and atomic staging
  v
/var/lib/radicale-backup/latest
  |
  |  nightly encrypted Restic snapshot
  v
private Cloudflare R2 repository
```

No new public hostname, Cloudflare route, router port, TLS certificate, or
Keycloak client is needed. The existing tunnel already forwards the entire
OpenCloud hostname, including the DAV paths, to OpenCloud.

## Settled design decisions

| Concern | Decision | Reason |
| --- | --- | --- |
| Deployment | Native NixOS `services.radicale`, not Docker | Matches the declarative host and uses the packaged systemd hardening. |
| Public ingress | Reuse `cloud.henhal.net` | OpenCloud owns authentication and DAV discovery; Radicale must not be public. |
| Client credentials | One revocable OpenCloud app token per device | Most DAV clients do not support OIDC; tokens avoid storing the Keycloak password. |
| Radicale authentication | `http_x_remote_user` | OpenCloud authenticates the request and supplies `X-Remote-User`. |
| Authorization | Explicit `owner_only` | Each authenticated user can access only collections under their own principal. |
| Web UI | Disabled | The upstream integration has no OpenCloud calendar UI, and exposing Radicale's UI would introduce a second authentication path. |
| Data path | `/srv/opencloud/radicale/collections` | Keeps irreplaceable data on the T7 while separating Radicale ownership from `/srv/opencloud/state`. |
| Backup input | Dedicated validated stage | Copying the live collection tree as an `extraPath` could capture an inconsistent write and would bypass per-source health reporting. |
| Backup failure | Retain last validated stage and mark the required source degraded | Other healthy sources can still be backed up, but the success heartbeat must not claim a complete recovery set. |

The direct Radicale listener is a security boundary. It must bind only to
`127.0.0.1:5232`; the firewall must not expose it on LAN, Tailscale, or public
interfaces. Because `http_x_remote_user` trusts a request header, opening this
port to another host would allow identity spoofing.

## Phase 1: Add the declarative Radicale service

Create `modules/features/cloud/opencloud-radicale.nix` with a focused module,
for example `flake.nixosModules.opencloudRadicale` and an enable option such as
`my.opencloudRadicale.enable`.

The module should:

1. Assert that `my.opencloud.enable` is enabled and the OpenCloud hostname is
   configured.
2. Enable `services.radicale` using the current stable package unless an
   integration incompatibility requires a reviewed override.
3. Configure:

   - `server.hosts = [ "127.0.0.1:5232" ]`
   - `server.ssl = false`, because the only hop is loopback
   - `auth.type = "http_x_remote_user"`
   - `rights.type = "owner_only"` explicitly
   - `web.type = "none"`
   - `storage.type = "multifilesystem"`
   - `storage.filesystem_folder = "/srv/opencloud/radicale/collections"`
   - `storage.folder_umask = "0077"`
   - predefined `def-addressbook` and `def-calendar` collections using JSON
     generated by Nix, with `VEVENT,VJOURNAL,VTODO` enabled for the calendar

4. Keep normal logging at `info`. Do not enable request headers, request
   content, response content, or bad PUT content logging in production because
   those may contain credentials, contact details, or calendar content.
5. Create `/srv/opencloud/radicale` and its `collections` directory with
   restrictive modes and `radicale:radicale` ownership using tmpfiles.
6. Extend `radicale.service` with:

   - `RequiresMountsFor=/srv/opencloud`
   - `ConditionPathIsMountPoint=/srv/opencloud`
   - ordering after the T7 mount

   This must fail closed rather than creating calendar data on HP's root
   filesystem when the T7 is absent.
7. Preserve the hardening already supplied by the NixOS module. Review the
   evaluated service to confirm that its `ReadWritePaths` permits only the
   configured collection directory and that no hardening override broadens
   access unnecessarily.

Import the module in `hosts/hp-server/configuration.nix` beside the other
OpenCloud modules and enable it there. Keep the feature HP-only.

### Phase 1 verification gate

Before deployment:

- Evaluate the final Radicale INI and OpenCloud YAML representation.
- Build `.#nixosConfigurations.hp-server.config.system.build.toplevel` on the
  workstation.
- Confirm the evaluated Radicale package version and generated systemd unit.
- Confirm `radicale.service` has the expected mount condition, ownership,
  read/write path, loopback address, and no firewall opening.

After deployment:

- Verify the T7 UUID and mount before starting Radicale.
- Confirm `radicale.service` is active and `ss` shows only
  `127.0.0.1:5232`.
- Inspect its journal for configuration, permission, or storage migration
  errors.
- Confirm an unauthenticated direct request cannot select an arbitrary user.

Do not continue to client setup if Radicale starts on the root filesystem,
listens beyond loopback, or accepts an untrusted identity.

## Phase 2: Configure OpenCloud as the authenticated DAV proxy

Extend `modules/features/cloud/opencloud.nix` using
`services.opencloud.settings.proxy.additional_policies`. Add the four routes
used by the upstream integration:

| Endpoint | Backend | Added header |
| --- | --- | --- |
| `/caldav/` | loopback Radicale | `X-Script-Name: /caldav` |
| `/.well-known/caldav` | loopback Radicale | `X-Script-Name: /caldav` |
| `/carddav/` | loopback Radicale | `X-Script-Name: /carddav` |
| `/.well-known/carddav` | loopback Radicale | `X-Script-Name: /carddav` |

Each route must set:

- `remote_user_header = "X-Remote-User"`
- `skip_x_access_token = true`
- the backend to the loopback Radicale listener

Use the URL form accepted by the installed OpenCloud `7.3.0` configuration.
The upstream Compose configuration uses `http://radicale:5232`; the NixOS wiki
currently shows `127.0.0.1:5232`. Resolve this during evaluation and a local
request test rather than copying either representation without verification.

Do not add an `unprotected` route and do not expose `/caldav/.web/`. The
OpenCloud proxy must authenticate every DAV request before it can set the
trusted user header.

The current account model should remain unchanged:

- Keycloak authenticates interactive users and enforces MFA.
- OpenCloud creates and owns app tokens.
- Radicale does not receive the user's Keycloak password and does not query
  Keycloak directly.
- A client uses the OpenCloud username as its DAV username and a generated
  OpenCloud app token as its password.

### Identity stability gate

Before importing real data, determine the exact value OpenCloud places in
`X-Remote-User` for the existing account and verify that it matches the DAV
username. Radicale uses this value in the collection path. Record the result in
`docs/CLOUD.md`.

Test what happens when a Keycloak login name is changed. The OpenCloud account
identifier is based on immutable `sub`, but the DAV principal may still use a
human-readable username. If a rename produces a new empty Radicale principal,
document username changes as a migration operation rather than claiming they
are transparent.

### Phase 2 verification gate

Using a disposable app token and test entries:

1. Verify `/.well-known/caldav` and `/.well-known/carddav` discovery through
   `https://cloud.henhal.net`.
2. Confirm a valid token can discover the predefined personal calendar and
   address book.
3. Confirm an invalid or revoked token is rejected.
4. Confirm one user cannot read or write another user's collection URL.
5. Create, edit, synchronize, and delete a disposable event, task, and contact.
6. Confirm contact photos and recurring events survive a round trip.
7. Confirm ordinary OpenCloud browser, desktop, Android, WebDAV, and Keycloak
   login flows still work.
8. Confirm no app token, authorization header, contact body, or calendar body
   appears in OpenCloud, Radicale, Alloy, or Loki logs.

## Phase 3: Add Radicale as a required Restic source

Extend `modules/features/backup/restic-s3.nix`; do not add the live collection
path to `my.hpBackup.extraPaths`.

### Staging layout

Use a dedicated root-owned staging area:

```text
/var/lib/radicale-backup/
├── latest/
│   ├── collections/
│   └── manifest.json
└── previous/              # temporary rollback generation during publication
```

The Restic snapshot path should be `/var/lib/radicale-backup/latest`, and the
status record should be `/var/lib/restic-status/radicale.json`.

### Consistent staging command

Add a `radicale-backup-stage` oneshot that follows the established source
pattern:

1. Acquire the existing exclusive `/var/lib/hp-backup/source.lock`.
2. Verify `/srv/opencloud` is a mount point with the configured T7 UUID.
3. Verify the collection directory exists, is readable, and has the expected
   Radicale ownership.
4. Stop `radicale.service` if it is active and confirm it is no longer active.
5. Run Radicale's storage verification against the stopped live collection.
   Use a dedicated generated verification config or the service's generated
   config without parsing an unstable `ExecStart` string. Treat any skipped or
   broken item as a failure.
6. Copy the collection tree to a private candidate directory with
   `rsync -aHAX --numeric-ids`.
7. Verify the staged candidate with Radicale as well, so a successful copy is
   not assumed to be a valid DAV store.
8. Write a manifest containing at least the timestamp, result, source path,
   consistency method, verification result, Radicale version, and OpenCloud
   version. Do not include contacts, event data, tokens, or secrets.
9. Atomically publish the candidate as `latest`, retaining the old validated
   output until publication succeeds.
10. Restart Radicale and verify that it becomes active. The cleanup trap must
    attempt restart after every failure path.

If any step fails, retain the previous `latest`, atomically write a degraded
status with a bounded error description, exit in the same controlled way as
the other auxiliary sources, and let Restic protect all other valid sources.
Radicale must nevertheless count as a required source, so the all-sources
status and external backup heartbeat remain degraded until a fresh valid stage
exists.

### Wire staging into the nightly job

Update the Restic module to:

- Add `/var/lib/radicale-backup/latest` to `backupPaths`.
- Add `radicale` to the required-source loop in `hp-backup-source-status`.
- Create the root-owned staging directories through tmpfiles.
- Define the staging oneshot.
- Add the oneshot to both `wants` and `after` for
  `restic-backups-hp-offsite.service`.
- Ensure the stage finishes before Restic's OpenCloud consistency preparation
  begins.
- Keep Radicale's interruption limited to verification and staging; it can run
  again while Restic uploads the immutable staged copy.

Do not fold Radicale into `/run/opencloud-backup/current`. Stopping OpenCloud
does not stop Radicale, so that would create a misleading shared consistency
boundary.

### Extend backup observability

Update the existing monitoring data path so Radicale is visible exactly like
the other required sources:

- Add `radicale` to
  `modules/features/monitoring/metrics/backup-status.sh`.
- Increase the required-source expected count in the backup dashboard from
  five to six.
- Update dashboard descriptions and documentation that enumerate sources.
- Reuse `BackupSourceDegraded`, `BackupSourceStillDegraded`, and
  `BackupSourceStatusStale`; no Radicale-specific duplicate alert is needed.
- Add `radicale.service` and `radicale-backup-stage.service` to HP's reviewed
  monitoring unit allowlist.
- Add `radicale.service` to full journal shipping only after confirming its
  production log level and redaction behavior are safe. Warning-and-higher
  journal shipping is sufficient initially.
- Add `radicale.service` to the important and critical systemd alert regexes.

The existing public probe of `https://cloud.henhal.net` proves the shared
ingress but not authenticated DAV behavior. Do not store a long-lived personal
app token in Prometheus or Blackbox Exporter solely to create an end-to-end
probe. Monitor Radicale's service state, restart count, loopback listener, and
backup source health; keep authenticated DAV checks in the deployment and
periodic recovery test.

### Phase 3 verification gate

1. Run the staging oneshot manually and inspect its status and manifest.
2. Confirm the live and staged collection trees compare with metadata
   preserved while the service was stopped.
3. Force a harmless validation failure in an isolated test path and confirm:

   - the prior `latest` remains intact;
   - the source becomes degraded;
   - Radicale restarts;
   - other sources can still be snapshotted;
   - the backup heartbeat does not claim a fully healthy set.

4. Run the full Restic job and confirm a new snapshot contains
   `/var/lib/radicale-backup/latest`.
5. Confirm `henhal_backup_source_healthy{source="radicale"}` becomes `1`, its
   timestamp is current, the required-source dashboard reads six of six, and
   the success heartbeat is delivered.

## Phase 4: Prove restoration before importing irreplaceable data

Perform the first restore into a temporary, isolated directory. Never restore
over the live collection tree for a test.

1. Select the new Restic snapshot and restore only
   `/var/lib/radicale-backup/latest` to a temporary target.
2. Check the manifest and file ownership/modes.
3. Run Radicale storage verification against the restored `collections` tree.
4. Start an isolated Radicale instance on a different loopback port with no
   public or tunnel exposure.
5. Access the isolated instance using a disposable local test identity and
   verify the restored event, task, contact, recurrence, and contact photo.
6. Record the tested commands and result in `docs/BACKUP.md`.
7. Delete the temporary restore only after the comparison is complete.

Add the production recovery outline to `docs/BACKUP.md`:

1. Disable public DAV access or stop OpenCloud during the replacement.
2. Stop Radicale.
3. Preserve the failed collection directory rather than immediately deleting
   it.
4. Restore the selected staged `collections` tree to a separate location.
5. Verify it with the matching or compatibility-tested Radicale version.
6. Use `rsync -aHAX --numeric-ids` to place it at
   `/srv/opencloud/radicale/collections` with `radicale:radicale` ownership.
7. Start Radicale and inspect its journal.
8. Test read and write through OpenCloud using a disposable app token.
9. Re-enable normal client use, run a fresh backup, and retain the pre-recovery
   snapshot until the service has remained stable.

The full HP/T7 recovery order should place Radicale after the T7 mount and
identity/OpenCloud recovery, but before the Cloudflare Tunnel is exposed.

## Phase 5: Configure clients and migrate data

### Per-device account setup

For every phone, tablet, or desktop client:

1. Generate a new OpenCloud app token in the user's settings. Name it after the
   device and client.
2. Configure the DAV client with:

   - server: `https://cloud.henhal.net`
   - username: the verified OpenCloud DAV username
   - password: that device's app token

3. Prefer automatic discovery. If a client requires explicit paths, use the
   discovered CalDAV/CardDAV URLs rather than inventing collection paths.
4. Enable the desired calendars and address books in the operating system.
5. Create a disposable item on the device, verify it on a second client, then
   delete it and confirm deletion synchronizes.
6. Revoke the app token when a device is lost, retired, or reconfigured.

Suitable client categories include Android DAV synchronizers, native iOS or
macOS CalDAV/CardDAV accounts, and desktop applications with standards-based
DAV support. Choose the exact clients during implementation and record their
tested setup screens in `docs/CLOUD.md`; do not make the server depend on a
vendor-specific client.

### Import existing data

Do not make the first import until the service, backup, and isolated restore
gates all pass.

1. Export contacts as vCard and calendars as iCalendar from the current
   provider. Preserve those exports offline until migration is accepted.
2. Import a small representative set first, including recurring events,
   reminders, Unicode names, multiple phone/email fields, birthdays, and
   contact photos.
3. Compare item counts and inspect representative records on at least two
   clients.
4. Import the remaining data once the sample round trip is correct.
5. Resolve duplicates before enabling bidirectional account sync broadly.
6. Run and verify a new Restic backup after the final import.
7. Keep the old provider read-only or retain its export for a reviewed overlap
   period before treating the self-hosted service as authoritative.

## Documentation changes during implementation

Update only after behavior is deployed and verified:

- `docs/CLOUD.md`
  - add Radicale to the service layout;
  - explain that OpenCloud has no calendar/contacts web UI;
  - document app-token creation, discovery URL, verified username semantics,
    tested clients, token revocation, and troubleshooting commands;
  - state that `cloud.henhal.net` remains the only public endpoint.
- `docs/BACKUP.md`
  - add Radicale to built-in sources and the client-to-R2 data flow;
  - document staging, status checks, backup interruption, individual restore,
    isolated verification, and full T7 recovery order;
  - change the expected required-source count from five to six.
- `docs/MONITORING.md` and the monitoring alert runbook
  - document Radicale service and backup-source metrics, alerts, logs, and
    expected remediation.

## Rollback plan

If the integration fails before real migration:

1. Revoke the disposable app tokens.
2. Disable the OpenCloud DAV routes and the Radicale feature declaratively.
3. Rebuild and verify ordinary OpenCloud and Keycloak flows.
4. Retain any test collection data and Restic snapshot until the cause is
   understood; remove it only through a separate reviewed cleanup.

If it fails after migration:

1. Stop writes by disabling client accounts or revoking their tokens.
2. Keep OpenCloud file service available if possible; Radicale failure should
   not require taking files offline.
3. Preserve the live tree, the latest validated stage, and relevant Restic
   snapshots.
4. Restore into isolation and compare before selecting a recovery point.
5. Temporarily return clients to the previous provider only if its retained
   data is known to be current; avoid two writable authorities.

## Final acceptance criteria

The feature is complete only when all of the following are true:

- Radicale is declarative, loopback-only, and fail-closed on the T7 mount.
- OpenCloud authenticates all DAV traffic and Radicale trusts no public client
  directly.
- Keycloak MFA and existing OpenCloud browser, desktop, Android, and WebDAV
  behavior are unchanged.
- One app token can be revoked without affecting other devices or browser
  sessions.
- Two independent clients can discover and synchronize calendar, task, and
  contact changes, including representative complex records.
- Users cannot access one another's collections.
- Logs and metrics contain no tokens or calendar/contact bodies.
- The Radicale stage validates, publishes atomically, and retains the previous
  validated output on failure.
- A successful nightly Restic snapshot contains the Radicale stage in R2.
- Radicale is a required healthy backup source and participates in the external
  success-heartbeat decision.
- An isolated Restic restore has been verified with Radicale and a DAV client.
- The migration source exports remain recoverable until the reviewed overlap
  period ends.
- The operational, monitoring, backup, and recovery documentation matches the
  deployed system.

## Known limitations to accept explicitly

- OpenCloud documents this integration as best-effort and outside its
  enterprise support offering.
- OpenCloud currently provides no calendar or contacts web interface.
- Service availability depends on HP, the T7, the Cloudflare Tunnel, and the
  existing OpenCloud identity path; offline-capable clients reduce disruption
  but are not backups.
- The recovery-point objective remains the nightly Restic schedule. A new or
  changed contact/event is not off-site protected until a successful snapshot
  includes a fresh healthy Radicale stage.
- Client interoperability varies. The acceptance matrix must be based on the
  actual phone and desktop clients that will be used.
