# Frequently used commands

**Remotely rebuild hp-server**

```bash
NIX_SSHOPTS='-o RemoteCommand=none' \
 nixos-rebuild switch \
 --flake path:/home/henhal/.dotfiles#hp-server \
 --target-host server-tailscale \
 --sudo \
 --ask-sudo-password
```

**Remotely rebuild lenovo-yoga-pro-7**

```bash
NIX_SSHOPTS='-o RemoteCommand=none' \
 nixos-rebuild switch \
 --flake path:/home/henhal/.dotfiles#lenovo-yoga-pro-7 \
 --target-host lenovo-yoga-pro-7 \
 --sudo \
 --ask-sudo-password
```

---

**Edit sops secrets**

```bash
nix run nixpkgs#sops -- secrets/monitoring.yaml
```

---

**Bootstrap a general-purpose development shell**

Run this from an existing project directory. It creates `flake.nix` and
`.envrc`, ensures `.direnv` is ignored by Git, allows the direnv configuration,
and opens the shell:

```bash
dev-init
```

An explicit directory is also supported:

```bash
dev-init /path/to/project
```

Existing files are preserved unless replacement is explicit:

```bash
dev-init --force
```

Inside a Git worktree, `dev-init` marks the generated flake as intent-to-add so
Nix can evaluate it. The file remains unstaged and still needs a normal `git
add` when you want to commit it.

---

**Check the monitoring stack on hp-server**

```bash
systemctl --no-pager --full status \
  prometheus alertmanager grafana loki alloy \
  prometheus-node-exporter prometheus-process-exporter \
  prometheus-blackbox-exporter monitoring-stack-heartbeat.timer

curl -fsS http://127.0.0.1:9090/api/v1/targets | jq -r '
  .data.activeTargets[]
  | [.labels.job, (.labels.host // ""), .labels.instance, .health, (.lastError // "")]
  | @tsv'
```

---

**Build all monitoring hosts without activating them**

```bash
nix build --no-link .#nixosConfigurations.hp-server.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.workstation.config.system.build.toplevel
nix build --no-link .#nixosConfigurations.lenovo-yoga-pro-7.config.system.build.toplevel
```

---
