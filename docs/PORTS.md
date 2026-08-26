# Service ports

This is the port lookup for the services declared by this flake. It records the
listener address, transport protocol, and access boundary. A port in this file
does not mean that the service is reachable from the whole network.

The tables reflect the checked-in configuration and live listeners checked on
the workstation and HP server on 2026-08-26. Disabled modules are listed
separately so they are not confused with active services.

## How to read the access boundaries

- `127.0.0.1` means that only processes on the same host can connect directly.
- `0.0.0.0` means that the process listens on host interfaces, but the firewall
  may still limit who can connect.
- `tailscale0` means that the NixOS firewall admits the port through the
  private tailnet interface only.
- A Cloudflare Tunnel URL is an HTTPS edge URL. The tunnel connects to a
  loopback origin on HP, so it does not create an inbound router port forward.
- An SSH forward gives a loopback service a temporary local browser URL. It does
  not change the service's bind address.

## Web interfaces

These are the URLs to try first.

| Service | Browser URL | Origin or listener | Access |
| --- | --- | --- | --- |
| OpenCloud | `https://cloud.henhal.net/` | HP `127.0.0.1:9200` | Cloudflare Tunnel |
| Keycloak | `https://auth.henhal.net/` | HP `127.0.0.1:8080` | Cloudflare Tunnel |
| Grafana | `https://monitor.henhal.net/` | HP `127.0.0.1:3000` | Cloudflare Tunnel, Keycloak and MFA |
| Sunshine web manager | `https://workstation.tail37a5eb.ts.net:47990/` | Workstation `0.0.0.0:47990/tcp` | Tailscale only; uses Sunshine's self-signed certificate |
| Syncthing | `http://127.0.0.1:8384/` | Each NixOS host `127.0.0.1:8384` | Local only, or use an SSH forward |
| Prometheus | `http://127.0.0.1:9090/` | HP `127.0.0.1:9090` | Local only, or use an SSH forward |
| Alertmanager | `http://127.0.0.1:9093/` | HP `127.0.0.1:9093` | Local only, or use an SSH forward |
| Loki HTTP API | `http://127.0.0.1:3100/` | HP `127.0.0.1:3100` | Local only; this is an API and readiness endpoint, not a dashboard |

Sunshine's browser interface is on `47990/tcp`. The separately opened
`47989/tcp` listener is Sunshine's non-TLS HTTP/control endpoint. Use the HTTPS
URL above for the web manager.

### Open a loopback web interface through SSH

For example, these forwards expose HP's Syncthing, Prometheus, and Alertmanager
interfaces on unused local ports:

```bash
ssh -o RemoteCommand=none -N \
  -L 18384:127.0.0.1:8384 \
  -L 19090:127.0.0.1:9090 \
  -L 19093:127.0.0.1:9093 \
  server-tailscale
```

Then open:

```text
http://127.0.0.1:18384  # Syncthing
http://127.0.0.1:19090  # Prometheus
http://127.0.0.1:19093  # Alertmanager
```

Use `workstation-tailscale` or the `laptop` SSH alias when the target is a
different host. Change the local side of `-L` if one of these ports is already
in use.

## Active service listeners

| Service | Host and listener | Protocol and port | Exposure or purpose |
| --- | --- | --- | --- |
| OpenCloud | HP `127.0.0.1:9200` | HTTP, TCP `9200` | Cloudflare origin for `cloud.henhal.net` |
| OpenCloud internal components | HP `127.0.0.1:9219`, `127.0.0.1:9220`, `127.0.0.1:19220` | HTTP, TCP `9219`, `9220`, `19220` | WebDAV debug, Search, and Graph component listeners; loopback only |
| Keycloak | HP `127.0.0.1:8080` | HTTP, TCP `8080` | Cloudflare origin for `auth.henhal.net` |
| Radicale | HP `127.0.0.1:5232` | HTTP, TCP `5232` | CalDAV/CardDAV backend called by OpenCloud; no standalone web UI |
| OpenLDAP | HP `127.0.0.1:1389` | LDAP, TCP `1389` | OpenCloud identity backend; loopback only |
| Grafana | HP `127.0.0.1:3000` | HTTP, TCP `3000` | Cloudflare origin for `monitor.henhal.net` |
| Prometheus | HP `127.0.0.1:9090` | HTTP, TCP `9090` | Metrics database and web UI |
| Alertmanager | HP `127.0.0.1:9093` | HTTP, TCP `9093` | Alert API and web UI |
| Loki | HP `127.0.0.1:3100` | HTTP, TCP `3100` | Log query and push API |
| Loki | HP `127.0.0.1:9096` | gRPC, TCP `9096` | Internal Loki listener; loopback only |
| Blackbox Exporter | HP `127.0.0.1:9315` | HTTP, TCP `9315` | Prometheus-only probe endpoint |
| Alloy | Workstation, Lenovo, and HP `127.0.0.1:12345` | HTTP, TCP `12345` | Local Alloy control endpoint; not a user-facing interface |
| Node Exporter | Workstation, Lenovo, and HP `0.0.0.0:9300` | HTTP, TCP `9300` | Scraped by HP through `tailscale0` only |
| Process Exporter | Workstation, Lenovo, and HP `0.0.0.0:9256` | HTTP, TCP `9256` | Scraped by HP through `tailscale0` only |
| Loki push proxy | HP `100.71.100.37:3101` | HTTP, TCP `3101` | Tailscale-only `/loki/api/v1/push` endpoint for Alloy |
| CUPS | Workstation and Lenovo `127.0.0.1:631` | HTTP/IPP, TCP `631` | CUPS default listener; the flake does not override this port |

The exporter processes listen on all addresses so HP can scrape them. The
firewall permits `9300` and `9256` only on `tailscale0`; they are not LAN or
public monitoring endpoints.

## Network, sync, and discovery ports

| Service | Hosts | Protocol and port | Notes |
| --- | --- | --- | --- |
| OpenSSH | All NixOS hosts | TCP `22` | Public-key SSH; the firewall allows it, with tailnet access explicitly allowed on `tailscale0` |
| Mosh | All NixOS hosts | UDP `60000-61000` | Session traffic after the SSH connection; firewall range is open for Mosh |
| Tailscale | All NixOS hosts | UDP `41641` | Tailscale's direct WireGuard port when selected; this is not an application UI |
| Syncthing transfer | All NixOS hosts | TCP `22000` | Default block transfer protocol; opened by `openDefaultPorts` and allowed on `tailscale0` |
| Syncthing QUIC transfer | All NixOS hosts | UDP `22000` | QUIC transfer protocol |
| Syncthing discovery | All NixOS hosts | UDP `21027` | Local network discovery; the Syncthing GUI remains on `127.0.0.1:8384` |
| Sunshine and Moonlight | Workstation | TCP `47984`, `47989`, `47990`, `48010` | Sunshine control and streaming set; admitted through `tailscale0` only |
| Sunshine and Moonlight | Workstation | UDP `47998`, `47999`, `48000`, `48002`, `48010` | Sunshine streaming and input transport; admitted through `tailscale0` only |
| KDE Connect | Workstation and Lenovo | TCP and UDP `1714-1764` | Device discovery and KDE Connect traffic |
| Avahi and mDNS | Workstation and Lenovo | UDP `5353` | Printer and local service discovery |
| Steam networking | Workstation | TCP `27015`, `27036`, `27037`; UDP `10400`, `10401`, `27015`, `27031-27036` | Firewall openings from Steam Remote Play and dedicated-server options; a port may have no listener when Steam is idle |

Syncthing's data ports are intentionally different from its web interface.
The data ports are network-facing according to the default firewall settings,
while the GUI is loopback-only.

## SSH development forwards

The `server`, `workstation`, and `workstation-tailscale` SSH profiles create
these local forwards when a matching SSH session is open. They are temporary
local listeners, not ports permanently owned by a NixOS service.

| Local port | Forwarded service |
| --- | --- |
| `3000` | Next.js |
| `5173` | SvelteKit |
| `54320` | Supabase database shadow |
| `54321` | Supabase API |
| `54322` | Supabase PostgreSQL |
| `54323` | Supabase Studio |
| `54324` | Supabase Inbucket |
| `54327` | Supabase analytics |
| `54329` | Supabase database pooler |
| `8081` | Metro Bundler |
| `8083` | Supabase edge-function inspector |
| `19000` | Expo development server |
| `19001` | Expo development client |
| `19002` | Expo Dev Tools |
| `19003` | Expo debugger |
| `38215` | AWS SSO login callback |
| `5037` | Android Debug Bridge server |
| `8888` | Dynamic SOCKS proxy, not a fixed remote service port |

The Nix-on-Droid SSH profile also forwards `9119` for the Hermes dashboard when
that optional dashboard is enabled.

## Declared but currently disabled

These modules define ports, but their host imports or enable flags are disabled
in the current checkout.

| Service | Listener or URL when enabled | Current state |
| --- | --- | --- |
| Firecrawl API | HP `127.0.0.1:3002` | The `firecrawl` module import is commented out; no public endpoint |
| Hermes dashboard | HP `127.0.0.1:9119`, nginx `127.0.0.1:9120`, then Tailscale Serve HTTPS | The `hermesRuntime` and `hermesDashboard` imports are commented out |
| Hermes Workspace | Local `127.0.0.1:3000`, Tailscale Serve HTTPS `3001` | The workspace import is commented out; `3000` is already Grafana's HP listener |
| Cockpit | HTTPS, TCP `9443` | The feature exists but is not imported by a current host |

## Configuration sources

- [Syncthing](../modules/features/network/syncthing.nix)
- [Sunshine](../modules/features/network/sunshine/sunshine.nix)
- [Tailscale and direct tailnet firewall rules](../modules/features/network/tailscale.nix)
- [SSH server](../modules/features/network/ssh-server.nix) and [SSH client forwards](../modules/features/network/ssh-config.nix)
- [OpenCloud](../modules/features/cloud/opencloud.nix), [Radicale](../modules/features/cloud/opencloud-radicale.nix), and [Keycloak](../modules/features/auth/keycloak.nix)
- [Monitoring hub](../modules/features/monitoring/hub.nix) and [host exporters](../modules/features/monitoring/exporter.nix)
- [KDE Connect](../modules/features/applications/kde-connect.nix), [printing and discovery](../modules/features/system/printer.nix), and [gaming](../modules/features/gaming.nix)
- [Current host imports](../hosts/workstation/configuration.nix), [Lenovo](../hosts/lenovo-yoga-pro-7/configuration.nix), and [HP](../hosts/hp-server/configuration.nix)

After changing a listener or firewall rule, check both the evaluated firewall
and the running sockets:

```bash
nix eval --json '.#nixosConfigurations.<host>.config.networking.firewall'
sudo ss -lntup
```
