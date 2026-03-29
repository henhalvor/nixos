# NixOS Dotfiles — Dendritic Pattern

Multi-system NixOS + Home Manager + nix-on-droid configuration built with the **Dendritic Pattern** using [flake-parts](https://flake.parts/) and [import-tree](https://github.com/vic/import-tree).

## Key Ideas

- **Named references, not file paths** — every module is exported as `self.nixosModules.<name>` and referenced by name. You can reorganize files without breaking anything.
- **Colocated NixOS + Home Manager** — a single feature file (e.g. `hyprland.nix`) defines both the system module and the user module. The NixOS module auto-injects the HM module via `home-manager.sharedModules`.
- **Standalone packages** — wrapped programs (kitty, nvim) can be run on any machine with `nix run .#kitty` without modifying the host.
- **Slim user modules** — user files contain only identity (account, SSH keys) and option values. All feature imports live at the host level.

## Hosts

| Host | Type | Primary DE | GPU |
|------|------|-----------|-----|
| `workstation` | Desktop | Hyprland | NVIDIA |
| `lenovo-yoga-pro-7` | Laptop | Niri (noctalia) | AMD |
| `hp-server` | Headless server | — | NVIDIA |
| `default` (nix-on-droid) | Android tablet | — | — |

## Directory Structure

```
new-config/
├── flake.nix                          # Inputs & mkFlake
├── hosts/
│   ├── workstation/                   # Desktop workstation
│   │   ├── default.nix                # nixosSystem entry point
│   │   ├── configuration.nix          # Feature imports + host settings
│   │   └── hardware-configuration.nix
│   ├── lenovo-yoga-pro-7/             # Laptop
│   │   ├── default.nix
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── hp-server/                     # Headless server
│       ├── default.nix
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── modules/
│   ├── flake-parts.nix                # Systems list + homeModules output
│   ├── features/                      # ~90 feature modules
│   │   ├── base.nix                   # Core NixOS settings (every host)
│   │   ├── hyprland.nix               # Colocated NixOS + HM (~520 lines)
│   │   ├── nvf.nix                    # Neovim (NixVim) + standalone pkg
│   │   ├── kitty.nix                  # Terminal + standalone pkg
│   │   ├── git.nix                    # Git with osConfig fallback
│   │   └── ...
│   ├── users/
│   │   └── henhal.nix                 # User identity + option values
│   ├── dev-shells/
│   │   ├── rust.nix                   # Rust toolchain (rust-overlay)
│   │   ├── react-native.nix           # RN + Android SDK + emulator
│   │   └── sandbox.nix                # FHS sandbox
│   └── nix-on-droid/
│       ├── default.nix                # nixOnDroidConfigurations.default
│       ├── basic-cli-tools.nix        # CLI essentials for Android
│       ├── ssh-client.nix             # Workstation SSH/mosh profiles
│       ├── termux.properties
│       └── .p10k-android.zsh
└── assets/
    └── wallpapers/
```

## Flake Outputs

| Output | Count | Description |
|--------|-------|-------------|
| `nixosConfigurations` | 3 | workstation, lenovo-yoga-pro-7, hp-server |
| `nixOnDroidConfigurations` | 1 | Galaxy Tab S10 Ultra |
| `nixosModules` | 100 | All features as named NixOS modules |
| `homeModules` | ~90 | Corresponding Home Manager modules |
| `packages` | 8 | Standalone wrapped programs (per arch) |
| `devShells` | 3 | rust, react-native, sandbox |

## Usage

### Rebuild a host

```bash
cd ~/.dotfiles/new-config
sudo nixos-rebuild switch --flake .#workstation
sudo nixos-rebuild switch --flake .#lenovo-yoga-pro-7
sudo nixos-rebuild switch --flake .#hp-server
```

### Run a standalone package

```bash
nix run .#kitty      # Launch configured kitty terminal
nix run .#nvim       # Launch configured Neovim
```

### Enter a dev shell

```bash
nix develop .#rust           # Rust toolchain + rust-analyzer
nix develop .#react-native   # React Native + Android SDK + emulator
nix develop .#sandbox        # FHS sandbox for prebuilt binaries
```

### Build nix-on-droid

```bash
nix-on-droid switch --flake .#default
```

### Validate

```bash
nix flake check              # Type-check all modules
nix build .#nixosConfigurations.workstation.config.system.build.toplevel --dry-run
```

## Adding a New Feature

Create a file anywhere under `modules/features/`. It's auto-discovered by import-tree.

```nix
# modules/features/my-tool.nix
{ self, inputs, ... }: {
  # NixOS module (imported by hosts)
  flake.nixosModules.myTool = { config, pkgs, ... }: {
    home-manager.sharedModules = [ self.homeModules.myTool ];
  };

  # Home Manager module (auto-injected by the NixOS module above)
  flake.homeModules.myTool = { config, pkgs, ... }: {
    home.packages = [ pkgs.my-tool ];
  };
}
```

Then add `self.nixosModules.myTool` to your host's `configuration.nix` imports.

## Adding a New Host

1. Create `hosts/my-machine/{default.nix,configuration.nix,hardware-configuration.nix}`
2. In `default.nix`: define `flake.nixosConfigurations.my-machine` using `inputs.nixpkgs.lib.nixosSystem`
3. In `configuration.nix`: import the features you need via `self.nixosModules.*`
4. Copy your `hardware-configuration.nix` from `/etc/nixos/`

See existing hosts for examples.

## Maintenance

```bash
nix flake update             # Update all inputs
nix flake check              # Validate after changes
git add -A                   # New files must be staged for flakes
```

## Documentation

- [Dendritic Migration Plan](docs/DENDRITIC_MIGRATION_PLAN.md) — full migration guide with templates
- [Desktop Configuration](docs/DESKTOP_CONFIGURATION.md) — desktop environment details

## Resources

- [Dendritic Pattern (vimjoyer)](https://www.vimjoyer.com/vid79-parts-wrapped)
- [flake-parts](https://flake.parts/)
- [import-tree](https://github.com/vic/import-tree)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
