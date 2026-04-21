# Copilot Instructions

## Build, test, and validation commands

- Full flake validation: `nix flake check`
- Fast validation without building derivations: `nix flake check --no-build`
- Rebuild a specific NixOS host: `sudo nixos-rebuild switch --flake .#<host>`
- Test a single NixOS host without switching permanently: `sudo nixos-rebuild test --flake .#<host>`
- Current host names: `workstation`, `lenovo-yoga-pro-7`, `hp-server`
- Rebuild nix-on-droid: `nix-on-droid switch --flake .#default`
- Run the installer/bootstrap flow: `bash install.sh`
- Enter the existing dev shells when needed: `nix develop .#rust`, `nix develop .#react-native`, `nix develop .#sandbox`

## High-level architecture

- `flake.nix` is intentionally small: it hands off to `flake-parts` and uses `import-tree` to auto-import every `.nix` file under `hosts/` and `modules/`. Adding a new host or feature usually does **not** require editing `flake.nix`.
- Files under `hosts/` and `modules/` are flake-parts modules and can contribute `flake.nixosModules.<name>`, `flake.homeModules.<name>`, `flake.nixosConfigurations.<name>`, `perSystem.packages.<name>`, and `perSystem.devShells.<name>`.
- Each NixOS host is split into three files:
  - `hosts/<name>/default.nix`: defines `flake.nixosConfigurations.<name>` and passes `specialArgs` like `inputs`, `self`, `pkgs-unstable`, and `pkgs24-11`
  - `hosts/<name>/configuration.nix`: imports named features and sets host-specific values
  - `hosts/<name>/hardware.nix`: wraps generated hardware config as a flake module
- Most user-facing features are defined as a paired NixOS + Home Manager module in one file. Hosts normally import `self.nixosModules.<feature>`, and the NixOS side injects the Home Manager side through `home-manager.sharedModules`.
- `modules/users/henhal.nix` is intentionally slim: it owns the user account plus shared `my.*` preference values. Hosts decide which features are enabled.
- `modules/nix-on-droid/default.nix` is the main exception to the NixOS pattern: it imports `self.homeModules.*` directly instead of going through the NixOS wrapper layer.

## Key conventions

- Reference modules by output name (`self.nixosModules.<name>` / `self.homeModules.<name>`), not by file path.
- Keep feature selection in `hosts/*/configuration.nix`. Keep `modules/users/henhal.nix` focused on identity and shared option values rather than feature imports.
- Feature-owned options live under `my.*`. The feature defines the option, the user module provides shared defaults, and hosts override per-machine values where needed.
- For user-space applications, prefer the repo’s standard pattern: define `flake.homeModules.<name>` for the actual Home Manager config and a thin `flake.nixosModules.<name>` wrapper that adds it through `home-manager.sharedModules`.
- NixOS hosts use `home-manager.backupFileExtension = "hm-backup"`; preserve that suffix because Obsidian stores its own `.backup` files. The nix-on-droid config uses `hm-bak` separately.
- When adding desktop helper scripts that may exist in multiple compositor modules, prefix the binary name with the compositor (`hyprland-`, `sway-`, `niri-`) to avoid Home Manager package collisions.
- Secrets are managed through `sops-nix`. Edit them with `nix-shell -p sops --run "sops secrets/secrets.yaml"`, keep the encrypted values in `secrets/secrets.yaml`, and add any new secret names to `modules/features/secrets.nix`.
- The Zen Browser module should keep MIME defaults pointed at `zen-beta.desktop`, not generated `userapp-*` desktop files.
- The Thunderbird module needs an explicit `programs.thunderbird.profiles.default` entry; enabling Thunderbird alone is not sufficient in this repo.
