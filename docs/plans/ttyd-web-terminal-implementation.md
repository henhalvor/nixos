# Secure ttyd Web Terminal Implementation Plan

Status: Implemented in repository; external provisioning and deployment pending

Created: 2026-08-07

Scope: Add a browser-accessible terminal gateway on `hp-server`, published as
`https://terminal.henhal.net` through the existing outbound-only Cloudflare
Tunnel and authenticated by a dedicated Keycloak realm with MFA. The gateway
will initially provide an HP terminal and is designed to add a separately
isolated terminal on a future headless coding server whose hostname is not yet
chosen.

Related documentation:

- [OpenCloud service and client guide](../CLOUD.md)
- [Monitoring](../MONITORING.md)

## Objective

Provide one authenticated web interface with an explicit target selector and a
persistent terminal on each configured headless host. The initial target is
`hp-server`; a future phase will add the planned coding server without creating
a second public ingress or weakening the authentication boundary. The
implementation must use the existing `my.opencloudTunnel` tunnel and make
Keycloak authentication, MFA, and explicit target authorization mandatory
before a WebSocket terminal can be opened.

This is remote **coding** access, not a replacement for administrative SSH.
Every target terminal will run as a host-local, dedicated, unprivileged
`webdev` user. It must not run as `root`, as an administrative wheel user, or
as a service account. Server administration, deployment, recovery, and secret
editing will continue over Tailscale SSH.

The implementation should use the versions already present in the locked
Nixpkgs input when this plan was written:

- `ttyd` 1.7.7
- `oauth2-proxy` 7.13.0

Re-evaluate those versions and their options from the lock file immediately
before implementation.

## Existing Infrastructure

The plan builds on these current facts rather than creating a parallel stack:

- `hp-server` hosts Keycloak at `127.0.0.1:8080` and publishes
  `auth.henhal.net` through Cloudflare Tunnel.
- `my.opencloudTunnel` owns tunnel ID
  `d5383138-72c4-4879-924a-319edc4c20c6` and already accepts explicit
  loopback-only `extraIngress` routes.
- The tunnel has a final `http_status:404` rule. No router port-forward is
  needed.
- Grafana demonstrates the current pattern of using a separate Keycloak realm
  for an infrastructure application.
- `hp-server` has only 8 GiB RAM. Builds and coding agents are already intended
  to run under bounded systemd slices.
- The future coding server will be a separate headless NixOS host reachable
  from HP over Tailscale. Its name, address, hardware, and repository paths
  remain intentionally unset until that machine exists.
- Keycloak's PostgreSQL database, including realm and client configuration, is
  included in the existing validated identity export and Restic source.

## Fixed Architecture

```text
Browser
  |
  | HTTPS + WebSocket
  v
Cloudflare edge
  |
  | existing outbound-only tunnel
  v
oauth2-proxy 127.0.0.1:4180 ----> auth.henhal.net/realms/terminal
  |
  | authenticated HTTP/WebSocket
  v
terminal gateway 127.0.0.1:4181
  |                         |
  | /hp/                    | /coding/ (future, fixed target)
  v                         v
HP ttyd                  coding-server ttyd
127.0.0.1:7681           <coding Tailscale IP>:7681
  |                         |
  v                         v
HP webdev tmux           coding webdev tmux
```

`ttyd` has no native Keycloak OIDC support. `oauth2-proxy` is therefore the
only origin exposed to Cloudflare and performs the authorization-code flow,
PKCE, role check, secure session-cookie handling, and WebSocket proxying. A
small loopback-only terminal gateway behind it serves a static target selector
and routes only the fixed paths `/hp/` and, later, `/coding/`. Each ttyd origin
requires the trusted identity header inserted by `oauth2-proxy` and preserved
by the gateway.

Use the NixOS nginx package for this gateway unless implementation testing
finds a smaller equally auditable packaged router. Multi-target path routing,
WebSocket forwarding, fixed upstream allowlisting, and the selector are now a
concrete requirement. Nginx must not perform a second OAuth flow or become a
public listener; `oauth2-proxy` remains the single authentication boundary.
The gateway must strip browser-supplied identity and forwarding headers before
setting the trusted header from the authenticated proxy request.

Use these initial values:

| Setting | Value |
| --- | --- |
| Public URL | `https://terminal.henhal.net` |
| Cloudflare origin | `http://127.0.0.1:4180` |
| Gateway origin | `http://127.0.0.1:4181` |
| HP target | `https://terminal.henhal.net/hp/` -> `http://127.0.0.1:7681` |
| Future coding target | `https://terminal.henhal.net/coding/` -> Tailscale-only ttyd origin |
| Keycloak issuer | `https://auth.henhal.net/realms/terminal` |
| Keycloak realm | `terminal` |
| Keycloak client ID | `ttyd` |
| OAuth callback | `https://terminal.henhal.net/oauth2/callback` |
| Required realm role | `ttyd-user` |
| Unix account | host-local `webdev` on every target |
| Persistent terminal | host-local tmux session `web` |

## Security Requirements

### Identity and authorization

- Create a separate `terminal` realm. Do not reuse the OpenCloud or monitoring
  realm, roles, users, or client credentials.
- Disable self-registration, password reset by email unless outbound mail is
  deliberately configured, social identity providers, and all unused flows.
- Create exactly one routine realm user, require a password change on first
  login, require TOTP and recovery-code enrollment, and keep the recovery
  codes offline.
- Enable Keycloak brute-force detection and use short, bounded realm session
  idle and maximum lifetimes. Start with a 30-minute SSO idle timeout and an
  8-hour maximum, then verify their interaction with `oauth2-proxy` cookies.
- Create only the `ttyd-user` realm role and assign it explicitly to the one
  user. `oauth2-proxy` must require this role; a valid account without the role
  must be denied. Do not authorize by email domain alone.
- Use a confidential Keycloak client with Standard Flow only. Disable Direct
  Access Grants, implicit flow, service-account roles, authorization services,
  and broad redirect wildcards.
- Use authorization code flow with PKCE `S256`, exact redirect URIs, and exact
  web origins. Validate that the token contains the role claim expected by the
  `keycloak-oidc` provider before enabling public ingress.

### Browser session boundary

- Configure a host-only secure cookie for `terminal.henhal.net`; do not set a
  parent-domain cookie shared with Cloud, Auth, or Monitor.
- Use `Secure`, `HttpOnly`, and `SameSite=Lax`, a unique cookie name, an
  independently generated cookie secret, and an expiration no longer than the
  Keycloak maximum session.
- Configure periodic cookie refresh so Keycloak-side revocation is noticed on
  subsequent HTTP authentication checks.
- Do not pass the OIDC access token or Authorization header to `ttyd`. Pass
  only the minimum user identity header required for ttyd's auth-proxy check.
- Enable issuer, audience, nonce, TLS, and email-verification checks. Do not use
  any `insecure-oidc-*` or issuer-verification bypass.
- Restrict redirect destinations to `terminal.henhal.net`; no open redirect or
  parent-domain wildcard is allowed.
- Record the important limitation explicitly in the operations guide: an
  already-established WebSocket is not guaranteed to close immediately when a
  Keycloak session is revoked. Bound exposure with ttyd connection lifecycle
  controls, the 8-hour maximum session, and a documented command that restarts
  `ttyd`/`oauth2-proxy` to terminate active browser access during an incident.

### Terminal, target, and Unix account boundary

- Declare a separate persistent `webdev` normal user on each terminal host,
  with its own host-local home, no wheel group, no trusted Nix role, no Docker
  group, no service groups, and no authorized SSH keys.
- Do not copy the `henhal` home, SSH keys, Git credentials, browser data,
  SOPS/age identities, Cloudflare credentials, Restic credentials, or
  application secrets into the account.
- Give each `webdev` only its own code workspace. Do not share its home or
  credentials between HP and the coding server. Clone repositories with a
  dedicated, least-privilege, host-specific Git credential only if pushing is
  required; a read-only deploy key is preferred when it is sufficient.
- Launch a fixed command, not a URL-selected command. Disable ttyd's URL
  argument feature and use `tmux new-session -A -s web` followed by the
  configured shell.
- Enable every ttyd instance's writable mode, base path, same-origin WebSocket
  check, auth-proxy header, and a single-client limit. Do not configure ttyd
  Basic Auth as a second, weaker password database.
- Run each ttyd instance under systemd as its local `webdev`, set `HOME`,
  `USER`, `LOGNAME`, a safe `PATH`, working directory, and `TERM` explicitly,
  and use a restrictive umask.
- Apply compatible systemd hardening (`PrivateTmp`, protected kernel controls,
  protected cgroups, restricted address families, and no device access beyond
  the allocated PTY). Do not apply filesystem protections that make the
  declared code workspace unusable.
- Set `NoNewPrivileges=true`. The web terminal must not run `sudo`, setuid
  helpers, or gain capabilities. Privileged work remains a Tailscale SSH task.
- Put every target's terminal workload in a bounded user/service slice. On HP,
  reuse the intent of `agent-build.slice`: cap memory and swap, limit tasks,
  and prevent a build or agent from starving SSH, Keycloak, OpenCloud,
  monitoring, and backup. Size the coding server's limits from its actual
  hardware rather than copying HP's limits.
- Decide and document whether coding processes persist in tmux after a browser
  disconnect. The initial design keeps the tmux session but permits only one
  browser client per target. Provide a target-specific administrative reset
  that kills the selected tmux session and restarts its ttyd service, plus a
  gateway-wide reset that terminates all active browser WebSockets.
- The target is selected only from a compiled/declarative allowlist. Never
  accept an arbitrary hostname, IP address, port, URL, command, or SSH
  destination from browser input, query parameters, headers, or path text.
- The selector must show target identity and availability clearly so a user
  cannot mistake an HP shell for the coding-server shell. Set a distinct shell
  prompt, tmux status, and terminal title on every host.

### Network and Cloudflare boundary

- Bind `oauth2-proxy` to `127.0.0.1:4180`, the gateway to
  `127.0.0.1:4181`, and HP ttyd to `127.0.0.1:7681`. None may be added to
  `networking.firewall`, Tailscale ingress, LAN ingress, or a router
  port-forward.
- On the future coding server, bind ttyd to that host's stable Tailscale
  address, never `0.0.0.0`. Permit its port on `tailscale0` only from HP's
  stable Tailscale address (`100.71.100.37` at the time this plan was written,
  to be re-verified before implementation). LAN, other tailnet peers, and
  public ingress must fail. Tailscale supplies encryption for the HP-to-coding
  hop.
- Add only `terminal.henhal.net` to
  `my.opencloudTunnel.extraIngress`, targeting the OAuth proxy. Never add the
  gateway or either ttyd port directly, and never install Cloudflare tunnel
  credentials on the coding server for this feature.
- Retain the tunnel's fail-closed 404 default and its existing root-only,
  tunnel-scoped credential.
- Create the DNS route on the existing `hp-opencloud` tunnel and add a cache
  bypass for the hostname. Confirm Cloudflare WebSocket support remains
  enabled.
- Do not initially layer Cloudflare Access in front of Keycloak. Keycloak is
  the application authentication boundary, and a second interactive identity
  flow complicates callback and WebSocket behavior. Any later Access policy is
  a separate defense-in-depth change with end-to-end testing.
- Apply Cloudflare rate limiting/WAF controls to the hostname where available,
  especially `/oauth2/*`, without caching, rewriting, or challenging the
  established WebSocket path.

### Logging and secret handling

- Create `secrets/ttyd.yaml` with only the confidential OIDC client secret and
  OAuth cookie secret. Add a narrow `.sops.yaml` rule for the two personal
  editing recipients and `hp-server`, matching the monitoring secret profile.
- Render an `oauth2-proxy` environment file under `/run/secrets-rendered` (or
  the sops-nix runtime equivalent) with root-only source ownership and the
  minimum service-readable permissions. No secret may enter a Nix string,
  derivation, command line, journal, Git diff, or generated config in the Nix
  store.
- Keep request logs useful but exclude query strings, cookies, authorization
  headers, OIDC codes, tokens, terminal input, terminal output, and environment
  contents.
- Never enable ttyd debug logging in production. Journald may record
  connection lifecycle and service errors only.
- Add the new services to the existing bounded monitoring journal selection,
  but do not ship shell contents or credentials to Loki.

## Planned Repository Changes

Implementation should remain a discrete feature rather than placing service
details directly in the host configuration.

### 1. Add reusable target and gateway modules

Add `modules/features/remote-access/ttyd-target.nix` and export a reusable
`self.nixosModules.ttydWebTerminalTarget`. It owns one host's `webdev`
account, workspace, resource slice, and hardened ttyd unit. Its interface must
distinguish a loopback HP target from a Tailscale-only remote target without
allowing arbitrary runtime destinations.

Add `modules/features/remote-access/ttyd-gateway.nix` and export
`self.nixosModules.ttydWebTerminalGateway` with an interface such as:

```nix
my.ttydWebTerminalGateway = {
  enable = true;
  publicHost = "terminal.henhal.net";
  authHost = "auth.henhal.net";
  secretFile = ../../secrets/ttyd.yaml;
  targets.hp = {
    displayName = "HP server";
    upstream = "http://127.0.0.1:7681";
    path = "/hp/";
  };
  # Add targets.coding only after its stable Tailscale identity exists.
};
```

The target module should own:

- the `webdev` user, group, home, workspace, and safe shell environment
- the resource-control slice
- a custom hardened `ttyd-web-terminal.service`
- listener/firewall behavior appropriate to local or remote target mode
- assertions that reject wildcard listeners and unsafe account privileges

The HP gateway module should own:

- assertions for a non-empty hostname, distinct ports, a declared secret file,
  Keycloak being enabled, and explicit loopback gateway listeners
- the packaged `services.oauth2-proxy` configuration using provider
  `keycloak-oidc`
- the loopback-only nginx target selector and WebSocket path router
- a declarative, fixed target allowlist with unique paths and upstreams
- sops-nix secret declarations and the runtime environment template
- service ordering and health/restart behavior
- no firewall openings

Prefer the packaged NixOS `services.oauth2-proxy` module. NixOS 25.11 exposes
the needed provider, issuer, listener, callback, upstream, cookie, key-file,
and `extraConfig` controls. Its single upstream is the local terminal gateway,
not a ttyd target. Use `extraConfig` only for verified flags that do not have a
typed module option, including the exact Keycloak role restriction.

Before committing the implementation, inspect the generated systemd command
and config to prove that secrets are environment references rather than Nix
store values.

### 2. Wire `hp-server`

In `hosts/hp-server/configuration.nix`:

- import both target and gateway modules
- enable the local target and gateway with the production hostnames, HP route,
  and SOPS file
- add `terminal.henhal.net` to the existing
  `my.opencloudTunnel.extraIngress`, targeting `127.0.0.1:4180` with the
  matching Host header
- extend monitoring's service allowlist with the ttyd and OAuth proxy unit
  names plus the gateway unit after verifying the generated names

Do not create another `services.cloudflared.tunnels` declaration or another
tunnel credential.

### 3. Add the future coding server without redesigning ingress

After its hostname, hardware, and stable Tailscale identity exist:

- import `ttydWebTerminalTarget` into that host only
- declare its host-local `webdev`, code workspace, resource limits, and ttyd
  base path `/coding/`
- bind ttyd to its stable Tailscale address and restrict the firewall source to
  HP's stable Tailscale address
- add one fixed `/coding/` upstream to HP's gateway target allowlist
- add exporter/service monitoring through the ordinary Tailscale monitoring
  path
- build and deploy the coding target first, test it from HP, then rebuild HP to
  publish the selector entry

Do not add another public hostname, tunnel, Keycloak realm, Keycloak client, or
browser credential for the coding server. An unavailable coding server should
show as unavailable while `/hp/` remains usable.

### 4. Extend operations documentation

After deployment, add an as-built section or dedicated runbook linked from
`docs/CLOUD.md` and `docs/MONITORING.md` covering:

- public URL and trust boundary
- target selection, unmistakable host identity, normal login, logout,
  disconnect, and per-host tmux persistence behavior
- checking both local health endpoints and the WebSocket path
- viewing redacted journals
- disabling ingress during an incident
- revoking the Keycloak user/client sessions
- rotating the client and cookie secrets
- resetting one target's tmux session and terminating all existing WebSockets
- recovering the realm from the existing Keycloak database export
- why privileged administration remains Tailscale SSH-only

## Implementation Phases

### Phase 0: Preflight and threat-model confirmation

1. Re-evaluate the locked ttyd and `oauth2-proxy` versions and NixOS module
   options.
2. Confirm ports 4180, 4181, and 7681 are unused on HP and that
   `terminal.henhal.net` is not already routed.
3. Inspect HP memory, disk space, and current service failures before adding a
   persistent coding workload.
4. Confirm `webdev` has no need for wheel, Docker, SOPS, production service
   credentials, or the existing `henhal` home. If any is claimed to be needed,
   stop and perform a separate privilege review rather than weakening this
   plan implicitly.
5. Define the initial resource limits from current HP headroom. Do not assume
   that an interactive Nix build fits merely because evaluation succeeds.

Exit gate: ports, capacity, account permissions, package options, and the
loopback-only request path are documented and accepted.

### Phase 1: Provision Keycloak and SOPS material

1. Create the `terminal` realm, its MFA/recovery-code policy, brute-force
   protection, session limits, the one user, and the `ttyd-user` role.
2. Create confidential client `ttyd` with the exact callback and origin.
3. Confirm role and audience claims by inspecting a test token locally without
   copying it into documentation or chat.
4. Generate independent high-entropy client and cookie secrets, create the
   scoped SOPS file/rule, and verify HP can decrypt it.
5. Take and validate the existing Keycloak logical export after provisioning.

Exit gate: MFA is mandatory, the authorized user has the explicit role, an
unassigned test identity is denied, secrets decrypt only to intended
recipients, and a fresh identity backup contains the realm.

### Phase 2: Implement and statically verify the Nix module

1. Add the reusable target and gateway modules, user boundary, resource
   controls, systemd units, sops-nix integration, and assertions.
2. Configure HP ttyd with base path `/hp/`, fixed command, writable terminal,
   same-origin check, proxy-auth header, one-client limit, loopback bind, and
   no URL arguments.
3. Configure `oauth2-proxy` with Keycloak OIDC, PKCE, explicit role check,
   secure host-only cookie, bounded lifetime, WebSocket proxying, loopback
   listener, and the local gateway upstream.
4. Configure the loopback gateway with a generated selector and the sole
   initial fixed route `/hp/` to HP ttyd. Strip untrusted forwarding and
   identity headers, restore only the authenticated identity header, and
   configure WebSocket upgrade forwarding explicitly.
5. Wire the modules and tunnel ingress into HP without opening firewall ports.
6. Evaluate the HP configuration, inspect generated units/config, run
   repository formatting applicable to changed Nix files, and run
   `git diff --check`.
7. Build `.#nixosConfigurations.hp-server.config.system.build.toplevel` on the
   workstation. Do not build this closure on constrained HP.

Exit gate: evaluation and workstation build pass; generated configuration
contains no secret values; listeners and privileges are demonstrably
fail-closed by construction.

### Phase 3: Deploy privately before public DNS

1. Transfer the workstation-built closure and activate it using the established
   remote workflow with `NIX_SSHOPTS='-o RemoteCommand=none'`.
2. Confirm the active generation and the OAuth proxy, gateway, and HP ttyd
   service states.
3. Verify with `ss` that only `127.0.0.1:4180`,
   `127.0.0.1:4181`, and `127.0.0.1:7681` listen and that the firewall has no
   matching openings.
4. Test the `/hp/` target only through `oauth2-proxy` using a temporary local
   SSH forward or host-resolution override. Direct unauthenticated requests to
   the gateway or ttyd must fail; unauthenticated proxy requests must redirect
   to the `terminal` realm.
5. Verify that the shell UID is `webdev`, `sudo`/setuid escalation fails,
   sensitive homes and runtime secrets are unreadable, and resource controls
   are attached to the intended cgroup.
6. Exercise terminal resize, copy/paste, reconnect, tmux attachment, concurrent
   client denial, large terminal output, browser disconnect cleanup, selector
   behavior, unknown-path denial, and unmistakable HP host labeling.

Exit gate: the private end-to-end flow works and all privilege, listener,
resource, and log-redaction checks pass before any public hostname exists.

### Phase 4: Publish through the existing tunnel

1. Create the DNS route on `hp-opencloud` for `terminal.henhal.net`.
2. Add/verify cache bypass, TLS mode, WebSocket behavior, and narrowly scoped
   rate-limit/WAF rules.
3. Confirm the tunnel configuration routes the hostname only to
   `127.0.0.1:4180` and unknown hostnames still receive 404.
4. Test from a machine outside the home network and from a clean private
   browser profile.

Exit gate: no terminal HTML or WebSocket upgrade is available before Keycloak
authentication; MFA is required; the authorized user works; role-less and
logged-out users are denied.

### Phase 5: Security and failure testing

Verify at minimum:

- wrong password, missing MFA, missing role, expired session, revoked session,
  and disabled user behavior
- OAuth `state`, nonce, issuer, audience, redirect, and PKCE enforcement
- cookies contain `Secure`, `HttpOnly`, correct SameSite, and host-only scope
- direct public access to 4180/4181/7681 and LAN access all fail; before the
  coding-server phase no terminal listener is reachable over Tailscale
- spoofed identity headers sent by the browser do not bypass the proxy
- a second browser client is rejected and cannot join the live PTY
- restarting ttyd terminates the active terminal; the incident reset also
  kills the persisted tmux session
- Keycloak or oauth2-proxy outage fails closed without exposing ttyd
- Cloudflare Tunnel outage affects only public reachability and does not cause
  another listener to appear
- no terminal I/O, cookie, code, token, secret, or sensitive query appears in
  journald, Loki, generated Nix files, or the Nix store
- resource limits contain a deliberate memory/CPU stress test without making
  SSH, Keycloak, OpenCloud, or monitoring unhealthy
- the existing Cloud, Auth, Monitor, backup, and monitoring checks remain
  healthy after activation

Explicitly test session revocation with an already-open terminal. If the
WebSocket remains usable, record that behavior and prove the incident-reset
procedure; do not claim instant revocation.

Exit gate: every test has recorded evidence, any limitation is in the runbook,
and there is no unexplained public, privilege, secret, or resource exposure.

### Phase 6: Monitoring and recovery handoff

1. Add service-up/restart visibility for HP ttyd, the gateway, and
   `oauth2-proxy` using the existing bounded monitoring patterns.
2. Add local health checks for the OAuth proxy/gateway and an
   authenticated-boundary black-box check that expects redirect/denial, not
   terminal content.
3. Alert on repeated service failures or the public endpoint becoming
   anonymously reachable. Do not monitor terminal content.
4. Complete the as-built operations documentation and secret-rotation
   procedure.
5. Run a new Keycloak logical export, validate it with `pg_restore --list`, and
   confirm the next Restic snapshot includes the updated identity export.

Exit gate: operations, incident response, monitoring, secret rotation, and
identity recovery are documented and tested.

### Phase 7: Add the future coding-server target

This phase is blocked by design until the machine exists and has a final NixOS
host definition and stable Tailscale identity.

1. Inspect the new machine's actual CPU, memory, storage, users, repository
   ownership, and Tailscale address; choose its permanent hostname separately.
2. Import and configure `ttydWebTerminalTarget` with base path `/coding/`,
   host-local `webdev`, and resource limits sized for that machine.
3. Deploy the coding server first. From HP, test its Tailscale-only ttyd origin,
   trusted-header rejection, firewall source restriction, host identity, tmux,
   privilege boundary, and resource controls. From another tailnet peer, prove
   the ttyd port is rejected.
4. Add the fixed `/coding/` target to HP's gateway allowlist, rebuild HP on the
   workstation, deploy HP, and verify the selector handles target availability
   without affecting `/hp/`.
5. Repeat all WebSocket, header-spoofing, single-client, log-redaction,
   revocation, incident-reset, monitoring, and failure tests for both targets.
6. Document and rehearse independent target disable/reset and gateway-wide
   emergency shutdown.

Exit gate: one Keycloak login presents exactly the two named targets; each
shell has unmistakable host identity and host-local isolation; the coding ttyd
origin accepts traffic only from HP over Tailscale; failure of either target
does not expose or disable the other.

## Deployment and Verification Commands

Use evaluated/generated unit names if they differ. The implementation runbook
should include commands equivalent to:

```bash
# Workstation: evaluate and build
XDG_CACHE_HOME=/tmp/codex-nix-cache \
  nix eval --raw .#nixosConfigurations.hp-server.config.system.build.toplevel

XDG_CACHE_HOME=/tmp/codex-nix-cache \
  nix build .#nixosConfigurations.hp-server.config.system.build.toplevel

# Workstation: activate the locally built closure remotely
NIX_SSHOPTS='-o RemoteCommand=none' \
  sudo nixos-rebuild switch --flake .#hp-server \
  --target-host server-tailscale --sudo --ask-sudo-password

# HP: runtime evidence
systemctl is-active \
  ttyd-web-terminal.service nginx.service oauth2-proxy.service
sudo systemctl --no-pager --full status \
  ttyd-web-terminal.service nginx.service oauth2-proxy.service
sudo ss -lntup | rg ':(4180|4181|7681)\b'
sudo journalctl \
  -u ttyd-web-terminal.service -u nginx.service \
  -u oauth2-proxy.service \
  --since '30 minutes ago' --no-pager -o short-iso
```

Do not treat a successful Nix evaluation, build, closure transfer, or
`nixos-rebuild` exit status as runtime proof. Listener ownership, service
journals, actual OIDC behavior, WebSocket behavior, privilege separation, and
the active generation all require post-activation checks.

## Rollback and Incident Response

### Normal rollback

1. Remove the `terminal.henhal.net` DNS route or replace its tunnel ingress
   with a fail-closed status before rolling back services.
2. Disable `my.ttydWebTerminalGateway.enable` and the HP target, then remove
   the `extraIngress` entry.
3. Rebuild on the workstation, activate HP, and verify 4180/4181/7681 no
   longer listen. If the coding-server phase has been deployed, disable its
   target module and verify its Tailscale listener is also gone.
4. Disable the Keycloak client. Retain the realm until logs, recovery, and
   rollback evidence have been reviewed.

Removing the public route first makes rollback fail closed even if an old
local service remains alive during activation.

### Suspected session or credential compromise

1. Disable the Cloudflare hostname/tunnel ingress immediately.
2. Disable the Keycloak user and client and revoke realm sessions.
3. Run the gateway-wide reset to kill `oauth2-proxy`, the gateway, every ttyd
   instance, and each host's `web` tmux session. Verify no child processes
   remain under either host's `webdev` account.
4. Rotate both the OIDC client secret and OAuth cookie secret; rotation of only
   the client secret does not invalidate every existing proxy cookie.
5. Review redacted Keycloak, OAuth proxy, gateway, Cloudflare, Tailscale,
   systemd, and filesystem evidence. Assume every file and credential readable
   by `webdev` on any reached target may have been exposed.
6. Re-enable only after the cause is understood and all access and recovery
   tests pass again.

## Acceptance Criteria

The implementation is complete only when:

- `terminal.henhal.net` is the sole public hostname for the feature and routes
  through the existing `my.opencloudTunnel` tunnel.
- Cloudflare reaches only `oauth2-proxy`; HP's proxy, gateway, and ttyd bind
  exclusively to loopback and no HP firewall port is opened.
- Keycloak's separate `terminal` realm, explicit role, one user, MFA, recovery
  codes, brute-force protection, and bounded sessions are verified.
- No ttyd terminal can be reached through the web gateway without a valid
  OAuth proxy session, and neither target selection nor URL arguments can
  choose an arbitrary command or upstream.
- Every shell runs only as that host's unprivileged `webdev`, cannot use
  sudo/setuid escalation, and cannot read administrative homes, root, SOPS,
  backup, tunnel, or service credentials.
- A single writable browser client per target can reconnect to its intended
  tmux session, while a second client for that target is denied.
- Browser-session revocation limitations and the tested hard-reset procedure
  are documented honestly.
- Resource controls prevent coding workloads from exhausting either host; HP's
  limits specifically protect its core services.
- Once the future server is added, its ttyd listener is reachable only from HP
  over Tailscale, the selector identifies both hosts unmistakably, and either
  target may fail or be disabled without exposing or disabling the other.
- Secrets exist only in SOPS and runtime secret files, not the Nix store,
  repository plaintext, process arguments, or logs.
- Runtime, external-network, negative-auth, failure, rollback, monitoring, and
  recovery tests all have recorded evidence.

## Deliberately Deferred

- privileged browser administration or a browser shell as `henhal`
- browser access to Docker, SOPS, Restic, systemd administration, or production
  service credentials
- Cloudflare Access as a second interactive authentication layer
- more than the one Keycloak user, shared PTYs, guest access, or per-project
  RBAC
- exposing an IDE, file browser, SSH endpoint, or additional web service
- moving builds or agents outside the existing bounded resource model

Each deferred item changes the threat model and requires a separate review.
