# Firecrawl on HP

NixOS keeps a root-owned checkout at `/var/lib/firecrawl/source`, fetches the
revision declared by `my.firecrawl.revision`, installs the local Compose
override, and starts the stack through `firecrawl.service`.

The API is available only at `http://127.0.0.1:3002`. Playwright is reachable
only on the private Compose network. No container receives the Docker socket.

Hermes MCP configuration should use:

```yaml
mcp_servers:
  firecrawl:
    command: npx
    args:
      - -y
      - firecrawl-mcp
    env:
      FIRECRAWL_API_URL: http://127.0.0.1:3002
```

Maintenance commands:

```bash
systemctl status firecrawl-bootstrap.service firecrawl.service
journalctl -u firecrawl-bootstrap.service -u firecrawl.service --since today
sudo docker compose \
  --env-file /run/secrets/rendered/firecrawl-env \
  -f /var/lib/firecrawl/source/docker-compose.yaml \
  -f /var/lib/firecrawl/firecrawl-override.yml \
  ps
```

Update by changing the 40-character revision in the Nix option and rebuilding
HP. Do not modify the managed checkout or recreate `.firecrawl-src` inside the
dotfiles repository.
