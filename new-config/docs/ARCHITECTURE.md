# Architecture

This document explains how the Dendritic Pattern works in this configuration.

## How It All Fits Together

```
flake.nix
  └─ inputs.flake-parts.lib.mkFlake
       └─ imports = [
            (inputs.import-tree ./hosts)    ← auto-discovers all .nix in hosts/
            (inputs.import-tree ./modules)  ← auto-discovers all .nix in modules/
          ]
```

Every `.nix` file under `hosts/` and `modules/` is automatically imported as a
**flake-parts module**. Each file can define any combination of:

- `flake.nixosModules.<name>` — a NixOS module
- `flake.homeModules.<name>` — a Home Manager module
- `flake.nixosConfigurations.<name>` — a full system configuration
- `perSystem.packages.<name>` — a standalone package
- `perSystem.devShells.<name>` — a development shell

Because `import-tree` loads everything, any file can reference any output via
`self.nixosModules.<name>` regardless of where it lives on disk.

## Module Patterns

### Pattern A: NixOS-only

For system-level features with no user-space component (e.g. bluetooth,
pipewire, networking).

```nix
# modules/features/bluetooth.nix
{ ... }: {
  flake.nixosModules.bluetooth = { ... }: {
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
  };
}
```

### Pattern B: HM-only (with NixOS wrapper)

For user-space programs. A thin NixOS wrapper injects the HM module so hosts
only need to import `self.nixosModules.X`.

```nix
# modules/features/direnv.nix
{ self, ... }: {
  flake.nixosModules.direnv = { ... }: {
    home-manager.sharedModules = [ self.homeModules.direnv ];
  };

  flake.homeModules.direnv = { ... }: {
    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;
  };
}
```

### Pattern B+: HM-only with configurable options

When the NixOS module defines `options.my.*` that get passed down to HM via
`osConfig`.

```nix
# modules/features/git.nix
{ self, ... }: {
  flake.nixosModules.git = { lib, ... }: {
    options.my.git = {
      userName = lib.mkOption { type = lib.types.str; };
      userEmail = lib.mkOption { type = lib.types.str; };
    };
    config.home-manager.sharedModules = [ self.homeModules.git ];
  };

  flake.homeModules.git = { config, osConfig, ... }: {
    programs.git = {
      enable = true;
      userName = osConfig.my.git.userName;
      userEmail = osConfig.my.git.userEmail;
    };
  };
}
```

The user module sets the values:

```nix
# modules/users/henhal.nix (inside the nixosModule)
my.git.userName = "Henrik";
my.git.userEmail = "henhalvor@gmail.com";
```

### Pattern C: Colocated NixOS + HM

For features that need both system-level and user-level config (e.g. window
managers, display managers).

```nix
# modules/features/hyprland.nix
{ self, inputs, ... }: {
  flake.nixosModules.hyprland = { config, lib, pkgs, ... }: {
    options.my.hyprland = { /* monitors, keybinds, etc. */ };
    config = {
      programs.hyprland.enable = true;
      home-manager.sharedModules = [ self.homeModules.hyprland ];
    };
  };

  flake.homeModules.hyprland = { config, pkgs, osConfig, ... }: {
    wayland.windowManager.hyprland = {
      enable = true;
      settings.monitor = osConfig.my.hyprland.monitors;
      # ... hundreds of lines of config
    };
  };
}
```

### Pattern D: Feature with standalone package

For programs that should be runnable via `nix run .#<name>` on any machine.

```nix
# modules/features/kitty.nix
{ self, ... }: {
  flake.nixosModules.kitty = { ... }: {
    home-manager.sharedModules = [ self.homeModules.kitty ];
  };

  flake.homeModules.kitty = { config, pkgs, ... }: {
    programs.kitty = {
      enable = true;
      # ... full config
    };
  };

  perSystem = { pkgs, ... }: {
    packages.kitty = pkgs.kitty;  # standalone: nix run .#kitty
  };
}
```

## Host Structure

Each host has three files:

```
hosts/<hostname>/
├── default.nix                # Entry point: nixosSystem + specialArgs
├── configuration.nix          # Feature imports + host-specific settings
└── hardware-configuration.nix # Auto-generated hardware config
```

### default.nix — Entry Point

Defines `flake.nixosConfigurations.<hostname>` using `nixpkgs.lib.nixosSystem`.
Sets up `specialArgs` (pkgs-unstable, pkgs24-11, etc.) and imports the
configuration + hardware modules by name.

```nix
{ self, inputs, ... }: {
  flake.nixosConfigurations.my-host = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; pkgs-unstable = ...; };
    modules = [ self.nixosModules.myHostConfig ];
  };
}
```

### configuration.nix — Feature Wiring

Imports features by name. This is the **only place** you add or remove features
for a host.

```nix
{ self, ... }: {
  flake.nixosModules.myHostConfig = { ... }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.networking
      self.nixosModules.hyprland
      self.nixosModules.kitty
      self.nixosModules.userHenhal
      # ... etc
    ];

    networking.hostName = "my-host";
    my.hyprland.monitors = [ ... ];
  };
}
```

## User Module

The user module is deliberately slim — identity only:

```nix
# modules/users/henhal.nix
{ self, ... }: {
  flake.nixosModules.userHenhal = { pkgs, ... }: {
    users.users.henhal = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" /* ... */ ];
      openssh.authorizedKeys.keys = [ /* ... */ ];
    };

    home-manager.users.henhal = {
      home.username = "henhal";
      home.homeDirectory = "/home/henhal";
      home.stateVersion = "25.05";
    };

    # Option values — features define the options, user sets the values
    my.theme = { /* ... */ };
    my.git.userName = "Henrik";
    my.git.userEmail = "henhalvor@gmail.com";
  };
}
```

Features define `options.my.*`, the user module sets their values, and hosts
decide which features to include.

## Nix-on-Droid

The Android configuration lives in `modules/nix-on-droid/`. It doesn't use
NixOS, so it imports `self.homeModules.*` directly instead of going through
the NixOS wrapper layer.

The `git.nix` feature handles this via an `osConfig` fallback:

```nix
osConfig = args.osConfig or {};
# if osConfig has my.git → use NixOS-level values
# else → use HM-level my.git options as fallback
```

## Dev Shells

Dev shells are defined in `modules/dev-shells/` using the `perSystem` submodule:

```nix
{ inputs, ... }: {
  perSystem = { system, pkgs, ... }: {
    devShells.rust = let
      toolchain = inputs.rust-overlay.packages.${system}.default;
    in pkgs.mkShell {
      packages = [ toolchain pkgs.rust-analyzer ];
    };
  };
}
```

Usage: `nix develop .#rust`

## Key Conventions

1. **Module names are globally unique** — `nvf` not `features-nvf` or
   `modules-features-nvf`.
2. **camelCase for module names** — `desktopCommon`, `sshServer`, `zenBrowser`.
3. **kebab-case for file names** — `desktop-common.nix`, `ssh-server.nix`.
4. **All features imported at host level** — never in user modules.
5. **`self` for same-flake references** — `self.nixosModules.X`,
   `self.homeModules.X`.
6. **`my.*` namespace for custom options** — `my.hyprland.monitors`,
   `my.theme.wallpaper`, `my.git.userName`.
7. **New files must be `git add`ed** — Nix flakes only see tracked files.

## Adding a New Feature

1. Create `modules/features/my-feature.nix`
2. Define `flake.nixosModules.myFeature` and optionally `flake.homeModules.myFeature`
3. `git add modules/features/my-feature.nix`
4. Add `self.nixosModules.myFeature` to the desired host's `configuration.nix`
5. `sudo nixos-rebuild switch --flake .#<host>`

## Adding a New Host

1. Create `hosts/my-host/` with `default.nix`, `configuration.nix`,
   `hardware-configuration.nix`
2. In `default.nix`: define `flake.nixosConfigurations.my-host`
3. In `configuration.nix`: import features via `self.nixosModules.*`
4. `git add hosts/my-host/`
5. `sudo nixos-rebuild switch --flake .#my-host`
