# Hermes Dashboard + Tailscale Serve

Exposes the local Hermes Web UI (bound to `127.0.0.1:9119`) across your
entire Tailscale tailnet using Tailscale Serve. No `--insecure` flag needed
— the dashboard stays on localhost, and a loopback-only nginx proxy rewrites
the Host header expected by Hermes before Tailscale proxies it with auto HTTPS
certs.

## How it works

1. A systemd service starts the Hermes dashboard bound to `127.0.0.1:9119`
2. nginx listens on `127.0.0.1:9120` and proxies to Hermes with
   `Host: 127.0.0.1:9119`
3. Before starting Hermes, the service calls `tailscale serve 9120` to
   register a tailnet proxy
4. Any device on your tailnet can access it at:

   ```
   https://<node-hostname>.tail<XXXX>.ts.net/
   ```

   where `<node-hostname>` is the MagicDNS name of the hp-server.

## Usage

Enable in your host configuration:

```nix
my.hermesDashboard = {
  enable = true;
  ownerUser = "henhal";
  dashboardPort = 9119;  # default
  proxyPort = 9120;      # default
};
```

## Verification

```bash
# On hp-server — check the proxy is registered
tailscale serve status

# From any tailnet device — open the dashboard
# https://hp-server-1.tail37a5eb.ts.net/
```

The service auto-restarts on failure. The `postStop` hook cleans up the
Tailscale Serve config when the service stops.
