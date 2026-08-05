# OpenCloud service and client guide

## Overview

OpenCloud provides the normal file service for documents, photos, music, and
files that should be accessible through the web, Linux desktop clients, and
Android. Files are stored on the HP server's dedicated T7 filesystem and are
protected off-site by the nightly Restic backup described in [BACKUP.md](BACKUP.md).

OpenCloud is not the owner of every file. `Vault` remains Syncthing-only,
`Shared` is a separate Syncthing folder, and active source-code repositories
remain Git/GitHub-managed.

## Service layout

| Component | Address and role |
| --- | --- |
| OpenCloud | `https://cloud.henhal.net`, serves files and client APIs |
| Keycloak | `https://auth.henhal.net`, sole interactive identity provider |
| Cloudflare Tunnel | Public HTTPS ingress; forwards only to loopback services on HP |
| OpenCloud service | `127.0.0.1:9200` on HP |
| Keycloak service | `127.0.0.1:8080` on HP |
| OpenCloud storage | `/srv/opencloud/state` on the UUID-mounted Samsung T7 |

Cloudflare Access must not be enabled for `cloud.henhal.net` or
`auth.henhal.net`: its browser-focused login layer breaks OIDC, desktop,
Android, and WebDAV flows. Cache bypass rules must remain active for both
hostnames.

OpenCloud uses Keycloak OIDC with MFA and automatic account provisioning into
the local OpenLDAP directory. The built-in OpenCloud identity provider is not a
routine-login fallback.

## Where files belong

### OpenCloud files

The Linux desktop client creates an account root such as:

```text
~/Cloud/
└── Personal/
    ├── Documents/
    ├── Pictures/
    │   └── Camera/
    ├── Music/
    └── Shared/
```

`~/Cloud` is only a container for OpenCloud Spaces. Files directly inside it
are not synchronized. Work normally inside `~/Cloud/Personal/...`; saving a
document, CAD file, or image there causes the desktop client to upload changes
to HP automatically.

Wait for the client to report that it is up to date before shutting down a
device or assuming the server has the newest version. Avoid editing the same
file on two devices at once, especially CAD files, because a conflict copy can
be created.

### Syncthing-only folders

```text
~/Vault   # Obsidian vault; all configured Syncthing peers, including HP
~/Shared  # general local sharing; Syncthing peers, including HP
```

Keep both outside `~/Cloud`. They are backed up through their HP-side staged
Syncthing sources, not through OpenCloud.

Do not place active Git repositories in either sync root. Use Git/GitHub; HP's
read-only mirrors and Restic provide the recovery layer.

## Browser and desktop use

1. Open `https://cloud.henhal.net` and sign in through Keycloak with MFA.
2. In OpenCloud Desktop, add `https://cloud.henhal.net` as the server.
3. Choose manual/advanced synchronization and set the account root to
   `~/Cloud`.
4. Select the Personal Space and the folders that should be materialized on
   that device.

Workstation should keep folders needing a complete offline copy fully
materialized. Configure Lenovo selectively according to travel and disk-space
needs. Offline placeholders are convenient but are not an independent backup.

## Android use and camera upload

The Android app uses the distinct Keycloak public client `OpenCloudAndroid`.
It signs in at `https://cloud.henhal.net` and redirects through Keycloak with
MFA. It does not use the desktop client ID.

To protect new phone photos:

1. Create `Personal/Pictures/Camera` in OpenCloud.
2. In the Android app, open **Settings -> Automatic picture uploads**.
3. Enable automatic picture upload and choose that destination.
4. Enable automatic video upload separately if wanted.
5. In Android system settings, grant **Photos and videos**, allow background
   data, and set the app's battery use to **Unrestricted**.
6. Keep the original camera file until it appears in OpenCloud and in a later
   Restic snapshot.

Android background work can be delayed by the operating system, so treat the
upload as eventually consistent rather than instant. Verify a new photo in the
web UI before relying on it as server-side data.

## Keycloak administration

Use `https://auth.henhal.net` to reach the Keycloak administration console.
Routine OpenCloud users belong in the `opencloud` realm; keep a separate
break-glass administrator and store its recovery information offline.

Each OpenCloud client type has its own public OIDC client:

| Client | Client ID | Redirect URI |
| --- | --- | --- |
| Web | `web` | `https://cloud.henhal.net/oidc-callback.html` and the other configured web callbacks |
| Linux desktop | `OpenCloudDesktop` | `http://127.0.0.1/*` |
| Android | `OpenCloudAndroid` | `oc://android.opencloud.eu` |

All native clients use authorization code flow with PKCE (`S256`) and no
client secret. Their access token must include the top-level multivalued
`roles` claim containing an OpenCloud role such as `opencloudUser`. Native
clients also need the optional `offline_access` client scope and the user's
realm-level `offline_access` role so short-lived access tokens can be renewed.

If Android or desktop requests begin failing with `token is expired`, verify
those two offline-access settings, then remove and re-add the affected account
to obtain fresh credentials. Never share a token, recovery code, or client
secret in logs.

## WebDAV and third-party clients

Use one revocable OpenCloud app token per WebDAV or third-party client. Do not
use the Keycloak/OpenCloud account password and do not reuse a token between
devices. Test token revocation after setup: removing one app token must not
affect browser, desktop, Android, or other clients.

## Operations and troubleshooting

### Expected backup outage

At 03:00 the nightly backup briefly stops OpenCloud for a consistent snapshot.
A temporary 502 from `cloud.henhal.net` during that interval is expected; it
should recover automatically when the job cleanup restarts OpenCloud.

Check service health:

```bash
systemctl is-active opencloud.service keycloak.service
systemctl is-active cloudflared-tunnel-d5383138-72c4-4879-924a-319edc4c20c6.service
sudo ss -lntp | rg ':(8080|9200)\b'
```

OpenCloud and Keycloak must only listen on loopback. An unauthenticated request
to the user API returning `401` is normal and confirms that the endpoint is
reachable but protected:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' \
  'https://cloud.henhal.net/ocs/v2.php/cloud/user?format=json'
```

### Client upload failure

After reproducing one failed Android or desktop upload, inspect HP's logs:

```bash
sudo journalctl -u opencloud.service --since '5 minutes ago' --no-pager -o short-iso | tail -n 250
sudo journalctl -u keycloak --since '15 minutes ago' --no-pager -o short-iso | tail -n 250
```

Do not paste bearer tokens into issue reports or chat. Error `token is expired`
means the client needs a refreshed OIDC session; it is not a Cloudflare upload
or destination-folder failure.

## Security and recovery reminders

- Files in OpenCloud are not independently backed up until the next successful
  HP Restic snapshot.
- The T7 must remain mounted at `/srv/opencloud`; OpenCloud is deliberately
  prevented from falling back to HP's root filesystem when it is absent.
- Keycloak MFA, recovery codes, the break-glass identity, SOPS identities, and
  Restic credentials are all part of the recovery plan.
- Follow [BACKUP.md](BACKUP.md) for verification, individual restores, and the
  full HP/T7 recovery procedure.
