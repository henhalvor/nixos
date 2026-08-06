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

---

**Edit sops secrets**

```bash
nix run nixpkgs#sops -- secrets/monitoring.yaml
```

---
