# Dendritic Pattern Migration Plan

Migration plan for converting the current NixOS / Home Manager flake to the **Dendritic Pattern** using `flake-parts`, `import-tree`, and `wrapper-modules`.

> **Reference:** [vimjoyer/nixconf](https://github.com/vimjoyer/nixconf) · [vimjoyer.com/vid79-parts-wrapped](https://www.vimjoyer.com/vid79-parts-wrapped)

---

## Table of Contents

- [Core Philosophy](#core-philosophy)
- [The Colocated Feature Pattern](#the-colocated-feature-pattern)
- [Target Directory Structure](#target-directory-structure)
- [Target flake.nix](#target-flakenix)
- [Pattern Templates](#pattern-templates)
- [Architectural Decisions](#architectural-decisions)
- [Migration Phases](#migration-phases)
- [File-by-File Mapping](#file-by-file-mapping)
- [Risks & Open Questions](#risks--open-questions)

---

## Core Philosophy

The central idea: **every feature is a single file** that colocates everything about that feature — the NixOS system config, the home-manager user config, and optionally a standalone wrapped package. Features reference each other **by name**, never by file path. A host simply lists which features it wants.

### What this eliminates

| Current pain | How dendritic solves it |
|---|---|
| `import ../../../nixos/modules/desktop/sessions/hyprland.nix` | `self.nixosModules.hyprland` |
| Duplicate dispatcher logic in `nixos/` and `home/` | Single colocated feature file |
| Editing `flake.nix` for every new module | `import-tree` auto-discovers files |
| Can't test a configured program standalone | `nix run .#kitty` works anywhere |
| Renaming/moving files breaks imports | Name-based references are path-independent |

---

## The Colocated Feature Pattern

A feature file can define up to **three things** in one place:

```nix
# modules/features/hyprland.nix
{ self, inputs, ... }: {

  # 1. NixOS module — system-level config
  #    Importing this in a host gives you the full feature.
  flake.nixosModules.hyprland = { pkgs, ... }: {
    programs.hyprland.enable = true;
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

    # Auto-inject the home-manager side for all users
    home-manager.sharedModules = [ self.homeModules.hyprland ];
  };

  # 2. Home-manager module — user-level config
  #    Injected automatically via sharedModules above,
  #    but also importable standalone (e.g. for nix-on-droid).
  flake.homeModules.hyprland = { pkgs, ... }: {
    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        "$mod" = "SUPER";
        bind = [ "$mod, Return, exec, kitty" ];
        # ...
      };
    };
  };

  # 3. Standalone package — run without rebuilding the OS
  #    `nix run .#hyprland` launches a fully configured hyprland.
  perSystem = { pkgs, ... }: {
    packages.hyprland = inputs.wrapper-modules.wrappers.hyprland.wrap {
      inherit pkgs;
      settings = { /* ... */ };
    };
  };
}
```

**Not every feature needs all three.** The pattern degrades gracefully:

| Feature type | nixosModules | homeModules | perSystem package | Example |
|---|:---:|:---:|:---:|---|
| Full desktop feature | ✓ | ✓ | ✓ | hyprland, niri, kitty |
| System service | ✓ | — | — | bluetooth, pipewire, tailscale |
| User config (with options) | ✓ (thin) | ✓ | — | git, ssh-config, secrets |
| User config (no options) | ✓ (thin) | ✓ | — | direnv, dev-tools, utils |
| Both levels, no package | ✓ | ✓ | — | gaming, printing |
| Package only | — | — | ✓ | noctalia (wrapped shell) |

> **"✓ (thin)"** means the `nixosModules` side only injects the `homeModules` via
> `sharedModules` — no NixOS-level config of its own. This keeps the
> "one import per feature" pattern consistent for hosts.

### How the injection works

When a host imports `self.nixosModules.hyprland`:

```
Host configuration.nix
  └── imports self.nixosModules.hyprland
        ├── Enables programs.hyprland (NixOS level)
        └── Adds self.homeModules.hyprland to home-manager.sharedModules
              └── Configures wayland.windowManager.hyprland (user level)
```

**One import, both levels activate.** No dispatcher needed.

---

## Target Directory Structure

```
.
├── flake.nix                              # Minimal: inputs + mkFlake + import-tree
├── flake.lock
│
├── hosts/                                 # One directory per machine (at repo root)
│   ├── workstation/
│   │   ├── default.nix                    # flake.nixosConfigurations.workstation
│   │   ├── configuration.nix              # flake.nixosModules.workstationConfig
│   │   └── hardware.nix                   # flake.nixosModules.workstationHardware
│   ├── lenovo-yoga-pro-7/
│   │   ├── default.nix
│   │   ├── configuration.nix
│   │   └── hardware.nix
│   └── hp-server/
│       ├── default.nix
│       ├── configuration.nix
│       └── hardware.nix
│
├── modules/
│   ├── flake-parts.nix                    # Systems list, homeModules option definition
│   ├── theme.nix                          # Shared theme data on flake outputs
│   │
│   ├── features/                          # Colocated feature files
│   │   │
│   │   │  # ── Desktop sessions ──
│   │   ├── hyprland.nix                   # nixosModules + homeModules + package
│   │   ├── niri.nix
│   │   ├── sway.nix
│   │   ├── gnome.nix
│   │   │
│   │   │  # ── Desktop components ──
│   │   ├── waybar.nix                     # nixosModules + homeModules + package
│   │   ├── hyprpanel.nix
│   │   ├── hyprlock.nix
│   │   ├── swaylock.nix
│   │   ├── hypridle.nix
│   │   ├── swayidle.nix
│   │   ├── rofi.nix
│   │   ├── mako.nix
│   │   ├── dunst.nix
│   │   ├── clipman.nix
│   │   ├── cliphist.nix
│   │   ├── grimblast.nix
│   │   ├── grim-screenshot.nix
│   │   ├── gammastep.nix
│   │   ├── wlogout.nix
│   │   ├── wayland-applets.nix
│   │   ├── noctalia.nix                   # Shell: bar + notifications + launcher
│   │   │
│   │   │  # ── Desktop infrastructure ──
│   │   ├── desktop-common.nix             # Shared Wayland/XDG config
│   │   ├── sddm.nix
│   │   ├── gdm.nix
│   │   │
│   │   │  # ── Applications ──
│   │   ├── kitty.nix                      # homeModules + package
│   │   ├── alacritty.nix
│   │   ├── wezterm.nix
│   │   ├── vivaldi.nix
│   │   ├── zen-browser.nix
│   │   ├── brave.nix
│   │   ├── firefox.nix
│   │   ├── google-chrome.nix
│   │   ├── edge.nix
│   │   ├── zsh.nix
│   │   ├── tmux.nix
│   │   ├── yazi.nix
│   │   ├── obsidian.nix
│   │   ├── spotify.nix
│   │   ├── vscode.nix
│   │   ├── cursor.nix
│   │   ├── gimp.nix
│   │   ├── gthumb.nix
│   │   ├── mpv.nix
│   │   ├── zathura.nix
│   │   ├── libreoffice.nix
│   │   ├── nautilus.nix
│   │   ├── mission-center.nix
│   │   ├── gnome-calculator.nix
│   │   ├── vial.nix
│   │   ├── nvf.nix                        # Neovim (via nvf flake)
│   │   ├── aider-chat.nix
│   │   ├── claude-code.nix
│   │   ├── amazon-q.nix
│   │   ├── opencode.nix
│   │   │
│   │   │  # ── System services ──
│   │   ├── bluetooth.nix                  # nixosModules only
│   │   ├── pipewire.nix
│   │   ├── networking.nix
│   │   ├── nvidia-graphics.nix
│   │   ├── amd-graphics.nix
│   │   ├── gaming.nix
│   │   ├── virtualization.nix
│   │   ├── syncthing.nix
│   │   ├── printer.nix
│   │   ├── external-io.nix
│   │   ├── android.nix
│   │   ├── bootloader.nix
│   │   ├── secure-boot.nix
│   │   ├── systemd-logind.nix
│   │   ├── battery.nix
│   │   ├── minimal-battery.nix
│   │   │
│   │   │  # ── Server ──
│   │   ├── ssh.nix
│   │   ├── tailscale.nix
│   │   ├── server-monitoring.nix
│   │   ├── sunshine.nix
│   │   ├── server-base.nix
│   │   │
│   │   │  # ── User config (option-based for multi-user) ──
│   │   ├── git.nix                        # nixosModules (thin) + homeModules (with options)
│   │   ├── ssh-config.nix
│   │   ├── nerd-fonts.nix
│   │   ├── secrets.nix
│   │   ├── udiskie.nix
│   │   ├── dev-tools.nix                  # nixosModules (thin) + homeModules
│   │   ├── direnv.nix
│   │   ├── session-variables.nix
│   │   ├── bottles.nix
│   │   ├── utils.nix                      # fzf, ripgrep, bat, fd, etc.
│   │   │
│   │   │  # ── Scripts ──
│   │   ├── power-monitor.nix
│   │   ├── yazi-float.nix
│   │   ├── brightness-external.nix
│   │   ├── toggle-monitors.nix
│   │   │
│   │   │  # ── Theme ──
│   │   └── stylix.nix                     # nixosModules + homeModules
│   │
│   ├── base.nix                           # flake.nixosModules.base (core system)
│   │
│   ├── users/
│   │   ├── henhal.nix                     # flake.nixosModules.userHenhal
│   │   └── henhal-android.nix             # Home-manager config for nix-on-droid
│   │
│   ├── dev-shells/                        # perSystem.devShells.*
│   │   ├── rust.nix
│   │   └── react-native.nix
│   │
│   └── nix-on-droid.nix                   # flake.nixOnDroidConfigurations
│
├── assets/                                # Wallpapers, images (unchanged)
├── docs/                                  # Documentation
└── scripts/                               # Setup scripts
```

---

## Target flake.nix

```nix
{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ... all other existing inputs (stylix, lanzaboote, nvf, etc.) ...
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        (inputs.import-tree ./hosts)
        (inputs.import-tree ./modules)
      ];
    };
}
```

That's it. No `nixosConfigurations` block, no `mkSystem` factory, no manual host wiring. `import-tree` discovers everything in both `hosts/` and `modules/` automatically.

---

## Pattern Templates

### Template A: NixOS-only feature (system service)

```nix
# modules/features/bluetooth.nix
{ ... }: {
  flake.nixosModules.bluetooth = { ... }: {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    services.blueman.enable = true;
  };
}
```

### Template B: Home-manager-only feature with options (user config)

Features that need user-specific values (name, email, keys) define **options** so
multiple users can set their own values without duplicating the feature file.

```nix
# modules/features/git.nix
{ self, ... }: {
  flake.homeModules.git = { lib, config, ... }: {
    options.my.git = {
      userName = lib.mkOption { type = lib.types.str; };
      userEmail = lib.mkOption { type = lib.types.str; };
    };

    config.programs.git = {
      enable = true;
      userName = config.my.git.userName;
      userEmail = config.my.git.userEmail;
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };
  };

  # Thin NixOS wrapper so hosts can import this like any other feature
  flake.nixosModules.git = { ... }: {
    home-manager.sharedModules = [ self.homeModules.git ];
  };
}
```

The user module only sets values — it never imports the feature:

```nix
# In modules/users/henhal.nix
home-manager.users.henhal.my.git = {
  userName = "Henrik";
  userEmail = "henhalvor@gmail.com";
};
```

A second user sets different values for the same options:

```nix
# In modules/users/alice.nix
home-manager.users.alice.my.git = {
  userName = "Alice";
  userEmail = "alice@example.com";
};
```

No duplicate git.nix needed.

### Template B2: Home-manager-only feature without options (no user-specific data)

Features with no user-specific data don't need options at all:

```nix
# modules/features/direnv.nix
{ self, ... }: {
  flake.homeModules.direnv = { ... }: {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  flake.nixosModules.direnv = { ... }: {
    home-manager.sharedModules = [ self.homeModules.direnv ];
  };
}
```

### Template C: Colocated feature (NixOS + home-manager, auto-injected)

```nix
# modules/features/hyprland.nix
{ self, inputs, ... }: {
  flake.nixosModules.hyprland = { pkgs, ... }: {
    programs.hyprland.enable = true;
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

    home-manager.sharedModules = [ self.homeModules.hyprland ];
  };

  flake.homeModules.hyprland = { pkgs, config, ... }: {
    wayland.windowManager.hyprland = {
      enable = true;
      settings = {
        "$mod" = "SUPER";
        bind = [
          "$mod, Return, exec, kitty"
          "$mod, Q, killactive"
        ];
        monitor = [
          # Host-specific monitors configured via NixOS options or overrides
        ];
      };
    };
  };
}
```

### Template D: Full feature (NixOS + home-manager + standalone package)

```nix
# modules/features/kitty.nix
{ self, ... }: {
  flake.nixosModules.kitty = { ... }: {
    home-manager.sharedModules = [ self.homeModules.kitty ];
  };

  flake.homeModules.kitty = { pkgs, ... }: {
    programs.kitty = {
      enable = true;
      settings = {
        font_family = "Hack Nerd Font Mono";
        font_size = 11;
        background_opacity = "0.9";
        # ... full kitty config ...
      };
    };
  };

  # `nix run .#kitty` — launches kitty with your config, no system rebuild needed
  perSystem = { pkgs, ... }: let
    kittyConfig = pkgs.writeText "kitty.conf" ''
      font_family Hack Nerd Font Mono
      font_size 11
      background_opacity 0.9
    '';
  in {
    packages.kitty = pkgs.symlinkJoin {
      name = "my-kitty";
      paths = [ pkgs.kitty ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/kitty \
          --add-flags "--config ${kittyConfig}"
      '';
    };
  };
}
```

### Template E: Feature with wrapper-modules (preferred for supported programs)

```nix
# modules/features/niri.nix
{ self, inputs, ... }: {
  flake.nixosModules.niri = { pkgs, ... }: {
    programs.niri.enable = true;
    programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;

    home-manager.sharedModules = [ self.homeModules.niri ];
  };

  flake.homeModules.niri = { ... }: {
    # Any home-manager-level niri config (environment vars, systemd services, etc.)
  };

  perSystem = { pkgs, lib, self', ... }: {
    packages.niri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.noctalia)
        ];
        input.keyboard.xkb.layout = "us,no";
        layout.gaps = 5;
        binds = {
          "Mod+Return".spawn-sh = lib.getExe pkgs.kitty;
          "Mod+Q".close-window = null;
        };
      };
    };
  };
}
```

### Template F: Host entry point

```nix
# hosts/workstation/default.nix
{ self, inputs, ... }: {
  flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.workstationConfig
    ];
  };
}
```

```nix
# hosts/workstation/configuration.nix
{ self, inputs, ... }: {
  flake.nixosModules.workstationConfig = { pkgs, ... }: {
    imports = [
      # Hardware
      self.nixosModules.workstationHardware

      # Core
      self.nixosModules.base
      inputs.home-manager.nixosModules.home-manager

      # Desktop (one import = NixOS + home-manager for each)
      self.nixosModules.desktopCommon
      self.nixosModules.hyprland
      self.nixosModules.sddm
      self.nixosModules.waybar
      self.nixosModules.hyprlock
      self.nixosModules.hypridle
      self.nixosModules.rofi
      self.nixosModules.cliphist
      self.nixosModules.grimblast
      self.nixosModules.mako
      self.nixosModules.wlogout
      self.nixosModules.waylandApplets
      self.nixosModules.gammastep

      # Applications (each auto-injects its home-manager config)
      self.nixosModules.kitty
      self.nixosModules.vivaldi
      self.nixosModules.zenBrowser
      self.nixosModules.zsh
      self.nixosModules.yazi
      self.nixosModules.obsidian
      self.nixosModules.spotify
      # ... etc

      # User-level features (also imported here, NOT in the user module)
      self.nixosModules.git
      self.nixosModules.sshConfig
      self.nixosModules.nerdFonts
      self.nixosModules.secrets
      self.nixosModules.udiskie
      self.nixosModules.devTools
      self.nixosModules.direnv
      self.nixosModules.sessionVariables
      self.nixosModules.bottles
      self.nixosModules.utils
      self.nixosModules.powerMonitor
      self.nixosModules.yaziFloat

      # System services
      self.nixosModules.pipewire
      self.nixosModules.bluetooth
      self.nixosModules.networking
      self.nixosModules.nvidiaGraphics
      self.nixosModules.gaming
      self.nixosModules.virtualization
      self.nixosModules.syncthing
      self.nixosModules.printer
      self.nixosModules.externalIo
      self.nixosModules.secureBoot
      self.nixosModules.ssh
      self.nixosModules.tailscale
      self.nixosModules.sunshine
      self.nixosModules.android

      # Theme
      self.nixosModules.stylix
      inputs.stylix.nixosModules.stylix

      # User (slim — just identity + option values)
      self.nixosModules.userHenhal
    ];

    networking.hostName = "workstation";

    # Workstation-specific config that doesn't belong in a feature
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
      package = pkgs.linuxPackages.nvidiaPackages.stable;
    };
  };
}
```

```nix
# hosts/workstation/hardware.nix
{ ... }: {
  flake.nixosModules.workstationHardware = { config, lib, modulesPath, ... }: {
    imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
    boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" ];
    # ... rest of hardware-configuration.nix ...
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  };
}
```

### Template G: User module (slim — identity + option values only)

The user module defines **who the user is** and sets values for option-based features.
It does **not** import features — the host decides what's installed.

```nix
# modules/users/henhal.nix
{ ... }: {
  flake.nixosModules.userHenhal = { pkgs, ... }: {
    # System-level identity
    users.users.henhal = {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" "docker" "video" "input" "i2c" ];
      shell = pkgs.zsh;
    };

    # Home-manager identity + option values for features
    home-manager.users.henhal = {
      home.username = "henhal";
      home.homeDirectory = "/home/henhal";
      home.stateVersion = "25.05";

      # Set values for option-based features (git, ssh, secrets, etc.)
      # The features themselves are imported at the HOST level, not here.
      my.git = {
        userName = "Henrik";
        userEmail = "henhalvor@gmail.com";
      };

      my.ssh = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
```

**Why this is slim:**
- No feature imports here — the host's `configuration.nix` imports all features
- Features auto-inject their home-manager config via `sharedModules`
- The user module only provides identity + user-specific option values
- Adding a second user means creating `modules/users/alice.nix` with different option values, nothing else

---

## Architectural Decisions

### 1. `homeModules` as a custom flake output

`flake-parts` doesn't have a built-in `homeModules` output. We register it in `flake-parts.nix`:

```nix
# modules/flake-parts.nix
{ inputs, ... }: {
  options.flake = inputs.flake-parts.lib.mkSubmoduleOptions {
    homeModules = inputs.nixpkgs.lib.mkOption {
      type = inputs.nixpkgs.lib.types.attrs;
      default = {};
      description = "Home-manager modules, importable standalone or injected via sharedModules";
    };
  };

  config = {
    systems = [ "x86_64-linux" "aarch64-linux" ];
  };
}
```

Now any feature file can set `flake.homeModules.foo = { ... };` and it will appear as `self.homeModules.foo`.

### 2. Where host-specific data lives

Currently, `hosts/*.nix` are pure-data attribute sets (hostname, monitors, GPU flags) consumed by a factory function. In the dendritic pattern, there's no factory function — each host is its own entry point.

**Decision:** Host-specific values (monitor layouts, GPU config, peripheral flags) live directly in the host's `configuration.nix`. They're already NixOS options or can be set directly. No intermediate data layer needed.

For values that multiple features need to read (e.g. "which monitors exist"), define them as NixOS options in a shared module and set them in the host.

### 3. Multiple nixpkgs channels

The current config uses `nixpkgs` (25.11), `nixpkgs-unstable`, and `nixpkgs-24-11`.

**Decision:** Expose unstable packages via a `perSystem` arg and pass through `specialArgs`:

```nix
# modules/flake-parts.nix (addition)
config.perSystem = { system, ... }: {
  _module.args.pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
};
```

In host entry points, pass through as `specialArgs`:

```nix
# hosts/workstation/default.nix
flake.nixosConfigurations.workstation = inputs.nixpkgs.lib.nixosSystem {
  specialArgs = {
    inherit inputs self;
    pkgs-unstable = import inputs.nixpkgs-unstable {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
  };
  modules = [ self.nixosModules.workstationConfig ];
};
```

### 4. The desktop dispatcher is eliminated

The current `lib/desktop.nix` resolver and the dual dispatchers in `nixos/modules/desktop/default.nix` and `home/modules/desktop/default.nix` are **no longer needed**. Each host explicitly imports the features it wants. Hyprland workstation imports `self.nixosModules.hyprland`; Niri laptop imports `self.nixosModules.niri`. Each feature auto-injects its home-manager config.

If you want "bundle" convenience, create a bundle module:

```nix
# modules/features/bundle-desktop-hyprland.nix
{ self, ... }: {
  flake.nixosModules.bundleDesktopHyprland = { ... }: {
    imports = [
      self.nixosModules.desktopCommon
      self.nixosModules.hyprland
      self.nixosModules.sddm
      self.nixosModules.waybar
      self.nixosModules.hyprlock
      self.nixosModules.hypridle
      self.nixosModules.rofi
      self.nixosModules.cliphist
      self.nixosModules.grimblast
      self.nixosModules.mako
      self.nixosModules.wlogout
      self.nixosModules.waylandApplets
      self.nixosModules.gammastep
    ];
  };
}
```

Then a host can just do `imports = [ self.nixosModules.bundleDesktopHyprland ];` for the full desktop stack.

### 5. Standalone packages

Programs that benefit from standalone packaging (those with meaningful configuration):

| Package | Wrapping approach | Run with |
|---|---|---|
| kitty | `symlinkJoin` + `makeWrapper --config` | `nix run .#kitty` |
| alacritty | `symlinkJoin` + `makeWrapper --config` | `nix run .#alacritty` |
| niri | `wrapper-modules` | `nix run .#niri` |
| noctalia | `wrapper-modules` | `nix run .#noctalia` |
| waybar | `symlinkJoin` + `makeWrapper --config` | `nix run .#waybar` |
| nvf/neovim | Already a flake — expose via `perSystem` | `nix run .#nvim` |
| zsh | `symlinkJoin` + custom zdotdir | `nix run .#zsh` |

Programs that are "just install it" (spotify, obsidian, gimp) don't need custom wrapping — they can still be exposed if desired: `packages.spotify = pkgs.spotify;`

### 6. Nix-on-Droid stays separate

Nix-on-droid uses its own builder (`nixOnDroidConfiguration`), not `nixosSystem`. It gets a standalone flake-parts module that defines `flake.nixOnDroidConfigurations`. The home-manager modules it shares with the main config (zsh, yazi, nvf, git) can be imported via `self.homeModules.*` since those are exported standalone.

### 7. `home-manager.sharedModules` applies to all users

Since every feature (including user-level ones like git, direnv, dev-tools) now injects via `sharedModules`, the modules are available to **all** users on a host. This is intentional — the host decides the feature set, and user modules only provide identity and option values.

For multi-user setups, this means all users get the same feature set but can configure features differently via their own `my.*` option values. If a feature truly needs to be user-specific (only user A gets it, not user B), import its `homeModules.*` directly in that user's `home-manager.users.*.imports` instead of relying on `sharedModules`.

### 8. User modules are slim — identity + option values only

User modules (`modules/users/henhal.nix`) contain:
- `users.users.henhal` — system account definition (groups, shell)
- `home-manager.users.henhal` — home identity (username, homeDirectory, stateVersion)
- `home-manager.users.henhal.my.*` — values for option-based features (git email, SSH key, etc.)

They do **not** import features. The host controls what's installed. This keeps user modules small and focused, and makes it trivial to add a second user — just create `modules/users/alice.nix` with different option values.

### 9. Option-based features for multi-user support

Features that need user-specific values (git username, SSH key path, etc.) define custom options under a `my.*` namespace:

```nix
options.my.git = {
  userName = lib.mkOption { type = lib.types.str; };
  userEmail = lib.mkOption { type = lib.types.str; };
};
```

This lets each user set their own values without duplicating the feature file. Features without user-specific data (direnv, dev-tools, utils) don't need options — they just work the same for everyone.

---

## Migration Phases

### Phase 0: Preparation

1. Create a migration branch: `git checkout -b dendritic-migration`
2. Ensure current config builds: `sudo nixos-rebuild build --flake .#workstation`

### Phase 1: Scaffold flake-parts

1. Add `flake-parts`, `import-tree`, `wrapper-modules` to flake inputs
2. Create `modules/flake-parts.nix` (systems list + `homeModules` option)
3. Rewrite `flake.nix` outputs to use `mkFlake` + `import-tree`
4. Create empty `hosts/` structure (directories only)
5. Verify: `nix flake check` (should pass with no outputs)

### Phase 2: Migrate one host end-to-end (workstation)

**Do one host completely before touching the others.** This validates the entire pattern.

1. Create `hosts/workstation/hardware.nix` — wrap existing `systems/workstation/hardware-configuration.nix` in flake-parts boilerplate
2. Create `modules/base.nix` — wrap `nixos/default.nix` as `flake.nixosModules.base`
3. Create a few critical features as colocated files:
   - `modules/features/pipewire.nix` (NixOS-only, simple)
   - `modules/features/bluetooth.nix` (NixOS-only, simple)
   - `modules/features/kitty.nix` (colocated + package)
   - `modules/features/hyprland.nix` (colocated, validates the full pattern)
   - `modules/features/zsh.nix` (colocated)
   - `modules/features/git.nix` (home-only)
4. Create `modules/users/henhal.nix` — the user module
5. Create `hosts/workstation/configuration.nix` — import all the above by name
6. Create `hosts/workstation/default.nix` — define `nixosConfigurations.workstation`
7. **Build and test:** `nix build .#nixosConfigurations.workstation.config.system.build.toplevel`
8. **Test standalone:** `nix run .#kitty`

### Phase 3: Migrate remaining NixOS features

Convert all remaining `nixos/modules/*.nix` files to named features under `modules/features/`. Work through them systematically:

**System services (NixOS-only):**
- networking, bootloader, nvidia-graphics, amd-graphics, gaming, virtualization, syncthing, printer, external-io, android, systemd-logind, secure-boot, battery, minimal-battery

**Server features:**
- ssh, tailscale, server-monitoring, sunshine, server-base

**Desktop infrastructure:**
- desktop-common, sddm, gdm

**Desktop sessions:**
- niri, sway, gnome (hyprland done in Phase 2)

### Phase 4: Migrate remaining home-manager features

Convert all `home/modules/**/*.nix` to colocated features or home-only features:

**Desktop components (colocated — NixOS + HM + optional package):**
- waybar, hyprpanel, swaylock, swayidle, rofi, mako, dunst, clipman, cliphist, grimblast, grim-screenshot, gammastep, wlogout, wayland-applets, noctalia

**Applications (colocated or home-only + optional package):**
- All ~30 application modules from `home/modules/applications/`

**User config (home-only):**
- ssh-config, nerd-fonts, secrets, udiskie, dev-tools, direnv, session-variables, bottles, utils

**Scripts (home-only):**
- power-monitor, yazi-float, brightness-external, toggle-monitors

**Theme (colocated):**
- stylix (both NixOS and home-manager sides)

### Phase 5: Migrate remaining hosts

1. `lenovo-yoga-pro-7` — same structure, imports niri instead of hyprland, plus battery/amd features
2. `hp-server` — no desktop features, just server + system modules
3. Delete the legacy `desktop` configuration

### Phase 6: Migrate supporting config

1. **Dev shells** → `modules/dev-shells/rust.nix`, `react-native.nix` (define `perSystem.devShells`)
2. **Nix-on-Droid** → `modules/nix-on-droid.nix` (imports `self.homeModules.*` for shared config)
3. **Theme data** → `modules/theme.nix` (export on `flake.theme`)

### Phase 7: Cleanup & validation

1. Build all hosts:
   ```bash
   nix build .#nixosConfigurations.workstation.config.system.build.toplevel
   nix build .#nixosConfigurations.lenovo-yoga-pro-7.config.system.build.toplevel
   nix build .#nixosConfigurations.hp-server.config.system.build.toplevel
   ```
2. Test standalone packages:
   ```bash
   nix run .#kitty
   nix run .#niri  # if wrapper-modules supports it
   ```
3. Test dev shells:
   ```bash
   nix develop .#rust
   ```
4. Delete old directories:
   - `hosts/*.nix` (old flat files)
   - `systems/`
   - `nixos/`
   - `home/`
   - `lib/`
   - `users/`
   - `shells/`
5. Update `docs/`, `README.md`, `scripts/create-new-config.sh`

---

## File-by-File Mapping

### Deleted (no longer needed)

| File | Reason |
|---|---|
| `lib/mk-nixos-system.nix` | Replaced by per-host `default.nix` |
| `lib/desktop.nix` | Dispatcher eliminated — explicit imports |
| `lib/theme.nix` | Absorbed into `modules/theme.nix` |
| `nixos/modules/desktop/default.nix` | NixOS dispatcher eliminated |
| `home/modules/desktop/default.nix` | Home dispatcher eliminated |
| `home/modules/desktop/lib.nix` | Helper functions no longer needed |
| `systems/desktop/` | Legacy — already marked for deletion |

### Hosts (restructured)

| Old | New |
|---|---|
| `hosts/workstation.nix` (data) + `systems/workstation/configuration.nix` | `hosts/workstation/configuration.nix` (merged) |
| `systems/workstation/hardware-configuration.nix` | `hosts/workstation/hardware.nix` |
| *(new)* | `hosts/workstation/default.nix` (entry point) |
| `hosts/lenovo-yoga-pro-7.nix` + `systems/lenovo-yoga-pro-7/configuration.nix` | `hosts/lenovo-yoga-pro-7/configuration.nix` |
| `systems/lenovo-yoga-pro-7/hardware-configuration.nix` | `hosts/lenovo-yoga-pro-7/hardware.nix` |
| `hosts/hp-server.nix` + `systems/hp-server/configuration.nix` | `hosts/hp-server/configuration.nix` |
| `systems/hp-server/hardware-configuration.nix` | `hosts/hp-server/hardware.nix` |

### NixOS modules → Named features

| Old | New feature name |
|---|---|
| `nixos/default.nix` | `base` (in `modules/base.nix`) |
| `nixos/modules/bluetooth.nix` | `bluetooth` |
| `nixos/modules/bootloader.nix` | `bootloader` |
| `nixos/modules/networking.nix` | `networking` |
| `nixos/modules/pipewire.nix` | `pipewire` |
| `nixos/modules/nvidia-graphics.nix` | `nvidiaGraphics` |
| `nixos/modules/gaming.nix` | `gaming` |
| `nixos/modules/virtualization.nix` | `virtualization` |
| `nixos/modules/syncthing.nix` | `syncthing` |
| `nixos/modules/printer.nix` | `printer` |
| `nixos/modules/external-io.nix` | `externalIo` |
| `nixos/modules/android.nix` | `android` |
| `nixos/modules/systemd-loginhd.nix` | `systemdLogind` |
| `nixos/modules/desktop/common.nix` | `desktopCommon` |
| `nixos/modules/desktop/sessions/hyprland.nix` | `hyprland` (colocated with HM) |
| `nixos/modules/desktop/sessions/niri.nix` | `niri` (colocated with HM) |
| `nixos/modules/desktop/sessions/sway.nix` | `sway` (colocated with HM) |
| `nixos/modules/desktop/sessions/gnome.nix` | `gnome` (colocated with HM) |
| `nixos/modules/desktop/display-managers/sddm.nix` | `sddm` |
| `nixos/modules/desktop/display-managers/gdm.nix` | `gdm` |
| `nixos/modules/server/default.nix` | `serverBase` |
| `nixos/modules/server/ssh.nix` | `ssh` |
| `nixos/modules/server/tailscale.nix` | `tailscale` |
| `nixos/modules/server/server-monitoring.nix` | `serverMonitoring` |
| `nixos/modules/server/sunshine/default.nix` | `sunshine` |
| `nixos/modules/theme/stylix.nix` | `stylix` (colocated with HM) |
| `systems/workstation/secure-boot.nix` | `secureBoot` |
| `systems/lenovo-yoga-pro-7/amd-graphics.nix` | `amdGraphics` |
| `systems/lenovo-yoga-pro-7/battery.nix` | `battery` |
| `systems/lenovo-yoga-pro-7/minimal-battery.nix` | `minimalBattery` |

### Home-manager modules → Named features (colocated or home-only)

| Old | New feature name | Type |
|---|---|---|
| `home/modules/desktop/sessions/hyprland.nix` | `hyprland` | Colocated (merged with NixOS) |
| `home/modules/desktop/sessions/niri.nix` | `niri` | Colocated |
| `home/modules/desktop/bars/waybar.nix` | `waybar` | Colocated + package |
| `home/modules/desktop/bars/hyprpanel.nix` | `hyprpanel` | Colocated |
| `home/modules/desktop/lock/hyprlock.nix` | `hyprlock` | Colocated |
| `home/modules/desktop/lock/swaylock.nix` | `swaylock` | Colocated |
| `home/modules/desktop/idle/hypridle.nix` | `hypridle` | Colocated |
| `home/modules/desktop/idle/swayidle.nix` | `swayidle` | Colocated |
| `home/modules/desktop/launchers/rofi.nix` | `rofi` | Colocated + package |
| `home/modules/desktop/clipboard/clipman.nix` | `clipman` | Colocated |
| `home/modules/desktop/clipboard/cliphist.nix` | `cliphist` | Colocated |
| `home/modules/desktop/screenshot/grimblast.nix` | `grimblast` | Colocated |
| `home/modules/desktop/screenshot/grim.nix` | `grimScreenshot` | Colocated |
| `home/modules/desktop/notifications/mako.nix` | `mako` | Colocated |
| `home/modules/desktop/notifications/dunst.nix` | `dunst` | Colocated |
| `home/modules/desktop/nightlight/gammastep.nix` | `gammastep` | Colocated |
| `home/modules/desktop/logout/wlogout.nix` | `wlogout` | Colocated |
| `home/modules/desktop/applets/wayland.nix` | `waylandApplets` | Colocated |
| `home/modules/desktop/shells/noctalia/` | `noctalia` | Colocated + package |
| `home/modules/applications/kitty.nix` | `kitty` | Home-only + package |
| `home/modules/applications/zsh.nix` | `zsh` | Home-only + package |
| `home/modules/applications/vivaldi.nix` | `vivaldi` | Home-only |
| `home/modules/applications/zen-browser.nix` | `zenBrowser` | Home-only |
| `home/modules/applications/yazi.nix` | `yazi` | Home-only |
| `home/modules/applications/nvf.nix` | `nvf` | Home-only + package |
| `home/modules/applications/obsidian.nix` | `obsidian` | Home-only |
| `home/modules/applications/spotify.nix` | `spotify` | Home-only |
| *(all other apps)* | *(same pattern)* | Home-only |
| `home/modules/settings/git.nix` | `git` | Option-based + thin NixOS |
| `home/modules/settings/ssh.nix` | `sshConfig` | Option-based + thin NixOS |
| `home/modules/settings/nerd-fonts.nix` | `nerdFonts` | Thin NixOS + HM |
| `home/modules/settings/secrets/` | `secrets` | Option-based + thin NixOS |
| `home/modules/settings/udiskie.nix` | `udiskie` | Thin NixOS + HM |
| `home/modules/environment/dev-tools.nix` | `devTools` | Thin NixOS + HM |
| `home/modules/environment/direnv.nix` | `direnv` | Thin NixOS + HM |
| `home/modules/environment/session-variables.nix` | `sessionVariables` | Thin NixOS + HM |
| `home/modules/environment/bottles.nix` | `bottles` | Thin NixOS + HM |
| `home/modules/utils/default.nix` | `utils` | Thin NixOS + HM |
| `home/modules/scripts/power-monitor.nix` | `powerMonitor` | Thin NixOS + HM |
| `home/modules/scripts/yazi-float.nix` | `yaziFloat` | Thin NixOS + HM |
| `home/modules/themes/stylix/` | `stylix` | Colocated (merged with NixOS) |

### Users

| Old | New |
|---|---|
| `users/henhal/home.nix` | `modules/users/henhal.nix` |
| `users/henhal-android/home.nix` | `modules/users/henhal-android.nix` |

### Other

| Old | New |
|---|---|
| `shells/rust/` | `modules/dev-shells/rust.nix` |
| `shells/js/react-native/` | `modules/dev-shells/react-native.nix` |
| `nix-on-droid/` | `modules/nix-on-droid.nix` + `modules/nix-on-droid-config/` |

---

## Risks & Open Questions

### Risks

1. **`home-manager.sharedModules` applies globally** — Every `nixosModules.X` that injects a `homeModules.X` applies it to ALL users on that machine. Fine for single-user; needs rethinking for multi-user.

2. **Module name collisions** — `import-tree` loads everything. Two files defining `flake.nixosModules.hyprland` will conflict. Names must be globally unique. Use the feature name mapping above consistently.

3. **`specialArgs` propagation** — Current features receive `hostConfig`, `desktop`, `userSettings`, `pkgs-unstable` via `specialArgs`. These need to be provided in each host's `nixosSystem` call, or features need to be rewritten to not depend on them (preferred).

4. **`homeModules` receiving `specialArgs`** — Home-manager modules injected via `sharedModules` don't automatically get NixOS `specialArgs`. Use `home-manager.extraSpecialArgs` in the host or user module to pass through what's needed.

5. **`wrapper-modules` availability** — Not all programs have wrappers. Check [BirdeeHub/nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules) before planning which programs to wrap. For unsupported programs, use `symlinkJoin` + `makeWrapper`.

6. **Option namespace collisions** — Features define options under `my.*` (e.g., `my.git.userName`). This namespace must not collide with other NixOS/HM options. Using a unique prefix like `my.*` or `dotfiles.*` avoids this.

### Open Questions

1. **Bundle modules vs. explicit imports?** — Should each host list every feature individually, or use bundle modules (e.g., `bundleDesktopHyprland`)? Bundles are convenient but hide which features are active. Start explicit, add bundles later if the import lists get unwieldy.

2. **Monitor config** — Currently passed as host data. In the new pattern, monitor layouts could be NixOS options set in the host's `configuration.nix` and read by desktop session features. Need to decide the option schema.

3. **Feature toggles** — The current null-defaulting pattern (set `null` → use session default) is elegant. Can we preserve something similar? One approach: bundle modules define the defaults, hosts override individual features by importing different ones.

4. **Noctalia all-in-one shell** — Currently, when `shell = "noctalia"`, the dispatcher auto-disables bar, notifications, and logout. In the dendritic model, the host simply imports `self.nixosModules.noctalia` instead of importing waybar + mako + wlogout separately. The conflict goes away naturally.

5. **Legacy `desktop` configuration** — Exclude from migration entirely, delete.
