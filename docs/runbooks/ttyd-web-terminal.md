# Secure Web Terminal Runbook

This runbook completes and operates the browser terminal at
`https://terminal.henhal.net`. The NixOS configuration publishes only
`oauth2-proxy` through the existing `my.opencloudTunnel`; nginx and ttyd remain
loopback-only on `hp-server`.

The HP shell is deliberately the unprivileged `webdev` account. It has no
sudo, SSH keys, SOPS identities, production credentials, or access to
`/home/henhal`. Administrative work remains available over Tailscale SSH.

## One-time control-plane setup

Do these steps before rebuilding HP. NixOS owns the local services, but the
Keycloak realm and Cloudflare DNS record are external state.

### Keycloak

In the Keycloak admin console at `https://auth.henhal.net`:

1. Create realm `terminal`. Disable registration and unused login flows.
2. Enable brute-force detection. Set SSO idle to 30 minutes and SSO maximum to
   8 hours.
3. Require OTP configuration for the realm's single routine user. Generate
   recovery codes and store them offline.
4. Create realm role `ttyd-user` and assign it only to that user.
5. Create confidential OIDC client `ttyd` with Standard Flow enabled. Disable
   Direct Access Grants, implicit flow, service accounts, authorization
   services, and broad wildcards.
6. Set the exact valid redirect URI to
   `https://terminal.henhal.net/oauth2/callback` and the exact web origin to
   `https://terminal.henhal.net`.
7. Copy the client secret from the encrypted repository file into Keycloak:

   ```bash
   nix shell nixpkgs#sops -c \
     sops decrypt --extract '["TTYD_OIDC_CLIENT_SECRET"]' secrets/ttyd.yaml
   ```

   Do not paste this value into shell history, issues, logs, or Nix files.
8. Verify a test token contains `ttyd-user` in its realm-role claim. A valid
   user without this role must be denied.

Take and validate the normal Keycloak PostgreSQL identity export afterward.

### Cloudflare

Create the public hostname/DNS route `terminal.henhal.net` on the existing
`hp-opencloud` tunnel. It must point to that tunnel, not directly to HP. Keep
WebSockets enabled, bypass caching for the hostname, and retain the tunnel's
final 404 rule. Do not create a router port-forward or second tunnel.

## Build and deploy

Run evaluation and the build on the workstation:

```bash
XDG_CACHE_HOME=/tmp/codex-nix-cache \
  nix eval --raw .#nixosConfigurations.hp-server.config.system.build.toplevel

XDG_CACHE_HOME=/tmp/codex-nix-cache \
  nix build .#nixosConfigurations.hp-server.config.system.build.toplevel
```

Then activate remotely:

```bash
NIX_SSHOPTS='-o RemoteCommand=none' \
  nixos-rebuild switch \
  --flake path:/home/henhal/.dotfiles#hp-server \
  --target-host server-tailscale \
  --sudo \
  --ask-sudo-password
```

## Post-activation verification

On HP, verify units and listeners:

```bash
systemctl is-active ttyd-web-terminal.service nginx.service oauth2-proxy.service
sudo ss -lntup | rg ':(4180|4181|7681)\b'
sudo systemctl --no-pager --full status \
  ttyd-web-terminal.service nginx.service oauth2-proxy.service
sudo journalctl \
  -u ttyd-web-terminal.service -u nginx.service -u oauth2-proxy.service \
  --since '30 minutes ago' --no-pager -o short-iso
```

Only `127.0.0.1:4180`, `127.0.0.1:4181`, and `127.0.0.1:7681` are expected.
Verify the firewall has no matching public or LAN openings.

From a clean browser outside the home network, prove:

- unauthenticated requests redirect to the `terminal` realm;
- MFA and the `ttyd-user` role are required;
- `/` shows only the fixed HP target and unknown paths return 404;
- `/hp/` opens a writable terminal whose `id` reports `webdev`;
- `/home/henhal`, runtime secrets, `sudo`, and privileged groups are unavailable;
- reconnecting attaches to tmux session `web` and a second client is rejected;
- logout prevents a new connection.

Revoking Keycloak may not immediately close an established WebSocket. Test and
record that behavior rather than assuming instant revocation.

## Routine operation and incident response

Reset only the HP terminal:

```bash
sudo -u webdev tmux kill-session -t web
sudo systemctl restart ttyd-web-terminal.service
```

Terminate all active browser access:

```bash
sudo systemctl stop oauth2-proxy.service nginx.service ttyd-web-terminal.service
sudo -u webdev tmux kill-session -t web
```

During suspected compromise, first disable the Cloudflare hostname, then
disable the Keycloak client/user and revoke realm sessions. Stop the services,
rotate both values in `secrets/ttyd.yaml`, update the Keycloak client secret,
rebuild, and retest. Rotating only the OIDC client secret does not invalidate
every existing oauth2-proxy cookie.

Treat every file or Git credential readable by `webdev` as exposed. HP should
normally have no persistent push credential. Prefer a short-lived login or a
repository-scoped, expiring credential and remove it afterward.

## Future coding server

Add `/coding/` only after the server has a final hostname and stable Tailscale
identity. Its ttyd listener must bind only to its Tailscale address and accept
the port only from HP's verified Tailscale address. HP remains the sole
Cloudflare-facing gateway.

Unlike HP's restricted account, the coding host may use a persistent personal
development account, rootless Nix/direnv/containers, scoped Git push
credentials, and password-protected sudo if accepted as a deliberate risk.
Never copy a workstation SSH private key or production/recovery secrets to it;
running `nixos-rebuild` from user-editable input is effectively root access.
