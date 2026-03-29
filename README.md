# NixOS Dotfiles — Dendritic Pattern

Multi-system NixOS + Home Manager + nix-on-droid configuration built with the
**Dendritic Pattern** using [flake-parts](https://flake.parts/) and
[import-tree](https://github.com/vic/import-tree).

## Core Ideas

- **Named references** — every module is `self.nixosModules.<name>`, referenced
  by name not file path. Reorganize freely without breaking anything.
- **Colocated NixOS + HM** — a single feature file defines both system and user
  config. The NixOS module auto-injects the HM module via
  `home-manager.sharedModules`.
- **Standalone packages** — wrapped programs can run on any machine with
  `nix run .#kitty` without touching the host system.
- **Slim users** — user modules contain only identity and option values. All
  feature imports live at the host level.

## Quick Reference

```bash
# Rebuild a host
sudo nixos-rebuild switch --flake .#workstation
sudo nixos-rebuild switch --flake .#lenovo-yoga-pro-7
sudo nixos-rebuild switch --flake .#hp-server

# Run a standalone package
nix run .#kitty
nix run .#nvim

# Enter a dev shell
nix develop .#rust
nix develop .#react-native
nix develop .#sandbox

# Nix-on-droid
nix-on-droid switch --flake .#default

# Validate
nix flake check
```

## Directory Layout

```
.
├── flake.nix                          # Inputs & mkFlake entry point
├── hosts/
│   ├── workstation/                   # Desktop — Hyprland, NVIDIA
│   ├── lenovo-yoga-pro-7/             # Laptop — Niri, AMD
│   └── hp-server/                     # Headless server
├── modules/
│   ├── flake-parts.nix                # Systems list + homeModules output
│   ├── features/                      # ~90 feature modules
│   ├── users/henhal.nix               # User identity & option values
│   ├── dev-shells/                    # rust, react-native, sandbox
│   └── nix-on-droid/                  # Galaxy Tab S10 Ultra config
└── docs/
    ├── ARCHITECTURE.md                # How the dendritic pattern works
    ├── FEATURES.md                    # Complete feature reference
    └── HOSTS.md                       # Per-host configuration details
```

## Flake Outputs

| Output | Count | Description |
|--------|-------|-------------|
| `nixosConfigurations` | 3 | workstation, lenovo-yoga-pro-7, hp-server |
| `nixOnDroidConfigurations` | 1 | Galaxy Tab S10 Ultra (aarch64) |
| `nixosModules` | 100 | All features as named NixOS modules |
| `homeModules` | ~90 | Corresponding Home Manager modules |
| `packages` | 8 | Standalone wrapped programs (per arch) |
| `devShells` | 3 | rust, react-native, sandbox |

## Documentation

- **[Architecture](docs/ARCHITECTURE.md)** — how the dendritic pattern works,
  module patterns, wiring, and conventions
- **[Features](docs/FEATURES.md)** — complete reference of all 90+ features
  organized by category
- **[Hosts](docs/HOSTS.md)** — per-host configuration details, enabled features,
  and host-specific settings

## Further Reading

- [Dendritic Pattern (vimjoyer)](https://www.vimjoyer.com/vid79-parts-wrapped)
- [flake-parts docs](https://flake.parts/)
- [import-tree](https://github.com/vic/import-tree)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
