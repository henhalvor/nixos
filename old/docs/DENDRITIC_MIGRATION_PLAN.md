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

## Step-by-Step Migration Guide

> **Strategy:** Build the new config in `new-config/`, test builds, then move contents to root.
> Each step lists the exact source file(s), target file, template pattern, and what to absorb.

### Phase 0: Scaffold ✅ DONE

Created `new-config/` with:
- `flake.nix` — mkFlake + import-tree on `./hosts` and `./modules`
- `modules/flake-parts.nix` — systems list + `homeModules` output definition
- `modules/base.nix` — stub for `nixosModules.base`
- `modules/users/henhal.nix` — stub for slim user module
- `modules/features/bluetooth.nix` — first migrated feature (reference example)
- `hosts/{workstation,lenovo-yoga-pro-7,hp-server}/{default,configuration,hardware}.nix` — stubs

---

### Phase 1: Core Infrastructure

These files form the foundation that every host needs.

#### Step 1.1 — `modules/base.nix` (nixosModules.base)

| Source | `nixos/default.nix` |
|---|---|
| **Template** | A (NixOS-only) |
| **Module name** | `nixosModules.base` |
| **What to include** | nix-ld, console keymap, docker, zsh enable, gvfs, gnome-disks, systemPackages (home-manager, os-prober, ntfs3g, dosfstools, ddcutil, usbutils), i2c support, udev rules (i2c + VIAL keyboard), basic locale/timezone (from `mk-nixos-system.nix` inline config) |
| **What NOT to include** | `nixpkgs.config.allowUnfree` (set per-host), `users.users.*` (user module handles this), noctalia systemPackages (noctalia feature), hostname (per-host) |
| **Notes** | Merge the inline base config from `lib/mk-nixos-system.nix` (the `{ config, pkgs, ... }: { ... }` block) into this module. Absorb `time.timeZone`, `i18n.defaultLocale`, `system.stateVersion` (or make stateVersion per-host). |

#### Step 1.2 — `modules/features/bootloader.nix` (nixosModules.bootloader)

| Source | `nixos/modules/bootloader.nix` |
|---|---|
| **Template** | A (NixOS-only) |
| **Module name** | `nixosModules.bootloader` |
| **What to include** | systemd-boot config (enable, configurationLimit=10, graceful), EFI settings, supportedFilesystems |
| **Notes** | This is the **default** bootloader. Workstation overrides via `secureBoot`. HP server has a custom GRUB bootloader (currently commented out — inline in hp-server hardware.nix). |

#### Step 1.3 — `modules/features/networking.nix` (nixosModules.networking)

| Source | `nixos/modules/networking.nix` |
|---|---|
| **Template** | A (NixOS-only) |
| **Module name** | `nixosModules.networking` |
| **What to include** | `networking.networkmanager.enable = true` |
| **What changes** | Remove `networking.hostName = hostname` — hostname is set per-host in configuration.nix. The `hostname` specialArg is eliminated. |

---

### Phase 2: Theme & Stylix

Stylix must be migrated early because many desktop components (bars, lock screens, rofi themes) depend on `config.lib.stylix.colors` and `config.stylix.fonts`.

#### Step 2.1 — `modules/features/stylix.nix` (nixosModules.stylix + homeModules.stylix)

| Source | `nixos/modules/theme/stylix.nix` + `home/modules/themes/stylix/default.nix` + `lib/theme.nix` |
|---|---|
| **Template** | C (Colocated NixOS + HM) |
| **Module names** | `nixosModules.stylix`, `homeModules.stylix` |
| **NixOS side** | Absorb `lib/theme.nix` logic inline. Define `stylix.enable`, `stylix.autoEnable`, `stylix.polarity`, `stylix.base16Scheme`, `stylix.image`, `stylix.cursor`, `stylix.fonts`. The scheme/wallpaper data currently comes from `userSettings.stylixTheme` — define `options.my.theme.*` so user modules can set scheme + wallpaper. |
| **HM side** | `stylix.targets.neovim.enable = false` + any other HM stylix target overrides. |
| **Notes** | Must also add `inputs.stylix.nixosModules.stylix` to the host imports (or import it from within this module). The wallpaper paths (`../assets/wallpapers/`) need to resolve from the new location — use `../../assets/wallpapers/` or pass as option. Consider defining `options.my.theme.scheme` and `options.my.theme.wallpaper` so user modules set values. |

---

### Phase 3: System Services (NixOS-only features)

All of these follow **Template A** — NixOS modules with no home-manager counterpart.

| Step | Source file | Feature name | Notes |
|---|---|---|---|
| 3.1 | `nixos/modules/pipewire.nix` | `pipewire` | Include the Sunshine virtual sink config. |
| 3.2 | `nixos/modules/external-io.nix` | `externalIo` | One-liner: `services.udisks2.enable = true`. |
| 3.3 | `nixos/modules/printer.nix` | `printer` | Uses `userSettings.username` — replace with NixOS option or hardcode "henhal" initially, then use `options.my.printer.user` or just `config.users.users` iteration. |
| 3.4 | `nixos/modules/android.nix` | `android` | Uses `userSettings.username` for groups — same approach as printer. |
| 3.5 | `nixos/modules/systemd-loginhd.nix` | `systemdLogind` | Logind settings + polkit. |
| 3.6 | `nixos/modules/nvidia-graphics.nix` | `nvidiaGraphics` | Session variables + xserver videoDrivers + hardware.graphics + NVIDIA settings. Workstation-specific NVIDIA config (from `systems/workstation/configuration.nix`) can either live in the host configuration.nix or be folded in here with options. |
| 3.7 | `nixos/modules/gaming.nix` | `gaming` | Steam, gamemode, wine, heroic, lutris, etc. |
| 3.8 | `nixos/modules/virtualization.nix` | `virtualization` | libvirtd, virt-manager, SPICE, QEMU. |
| 3.9 | `nixos/modules/syncthing.nix` | `syncthing` | Uses `userSettings.username/homeDirectory` — replace with options or config introspection. Includes the systemd directory-creation service. |
| 3.10 | `systems/workstation/secure-boot.nix` | `secureBoot` | Lanzaboote config. Must also add `inputs.lanzaboote.nixosModules.lanzaboote` in its module or require host to import it. |
| 3.11 | `systems/lenovo-yoga-pro-7/amd-graphics.nix` | `amdGraphics` | AMD-specific session variables + Vulkan config. |
| 3.12 | `systems/lenovo-yoga-pro-7/minimal-battery.nix` | `minimalBattery` | powertop, tuned, upower, networkmanager powersave. Absorbs `systems/lenovo-yoga-pro-7/battery.nix` (which is the unused alt). |
| 3.13 | `systems/workstation/scripts/boot-windows.nix` | `bootWindows` | Boot-windows script. Currently a NixOS systemPackages entry — keep as NixOS feature. The user's xdg.desktopEntries entry (from `users/henhal/home.nix`) should also move here as an HM module, making this colocated. |
| 3.14 | `systems/hp-server/laptop-server.nix` | `laptopServer` | Lid-close ignore, performance governor. HP server specific. |

---

### Phase 4: Server Features (NixOS-only)

| Step | Source file | Feature name | Notes |
|---|---|---|---|
| 4.1 | `nixos/modules/server/default.nix` | `serverBase` | htop, iftop, iotop packages + nix-collect-garbage cron job. |
| 4.2 | `nixos/modules/server/ssh.nix` | `sshServer` | openssh config + mosh. Uses `userSettings.username` for authorized keys — replace with option. **Name:** `sshServer` (not `ssh`) to avoid collision with SSH client feature. |
| 4.3 | `nixos/modules/server/tailscale.nix` | `tailscale` | Simple enable + trusted firewall interface. |
| 4.4 | `nixos/modules/server/server-monitoring.nix` | `serverMonitoring` | Prometheus + Grafana setup. |
| 4.5 | `nixos/modules/server/sunshine/default.nix` | `sunshine` | Sunshine streaming + CUDA + Avahi. Absorb `sunshine-monitor-setup.nix` and `sunshine-monitor-restore.nix` scripts (they're imported by hyprland HM session — move script derivations here, export them for hyprland to reference). |
| 4.6 | `nixos/modules/server/cockpit.nix` | `cockpit` | Currently unused (commented out). Migrate anyway for completeness. |

---

### Phase 5: Desktop Foundation

#### Step 5.1 — `modules/features/desktop-common.nix` (nixosModules.desktopCommon + homeModules.desktopCommon)

| Source | `nixos/modules/desktop/common.nix` + `home/modules/desktop/common.nix` |
|---|---|
| **Template** | C (Colocated) |
| **Module names** | `nixosModules.desktopCommon`, `homeModules.desktopCommon` |
| **NixOS side** | XKB layout (no), XDG portal enable + gtk portal, dconf enable, Noto fonts. |
| **HM side** | playerctl/brightnessctl/pamixer packages, xdg.enable, TERMINAL/BROWSER session vars. Currently reads `userSettings.term/browser` — replace with `options.my.desktop.terminal` and `options.my.desktop.browser` set by user module. |

#### Step 5.2 — `modules/features/sddm.nix` (nixosModules.sddm)

| Source | `nixos/modules/desktop/display-managers/sddm.nix` |
|---|---|
| **Template** | A (NixOS-only) |
| **Module name** | `nixosModules.sddm` |
| **What to include** | SDDM enable + astronaut theme with Stylix integration. References `config.stylix.*` and `config.lib.stylix.colors` — Stylix must be imported before this feature on the host. |

#### Step 5.3 — `modules/features/gdm.nix` (nixosModules.gdm)

| Source | `nixos/modules/desktop/display-managers/gdm.nix` |
|---|---|
| **Template** | A (NixOS-only) |
| **Module name** | `nixosModules.gdm` |

---

### Phase 6: Desktop Sessions (Colocated — the most complex features)

Each window manager merges its NixOS module + home-manager module + host-specific scripts into a single feature file. These are the largest and most complex migrations.

#### Step 6.1 — `modules/features/hyprland.nix` ⭐

| Source | `nixos/modules/desktop/sessions/hyprland.nix` + `home/modules/desktop/sessions/hyprland.nix` |
|---|---|
| **Template** | C (Colocated) or D (with standalone package) |
| **Module names** | `nixosModules.hyprland`, `homeModules.hyprland` |
| **NixOS side** | `programs.hyprland.enable`, xdg-desktop-portal-hyprland, PAM hyprlock, custom session desktop entry, wayland session variables, video group, `programs.light.enable`. |
| **HM side** | Full hyprland config: keybindings, monitor rules, workspace rules, exec-once, animations, etc. |
| **Scripts to absorb** | `home/modules/scripts/toggle-monitors-workstation-hyprland.nix`, `home/modules/scripts/brightness-external.nix`, `nixos/modules/server/sunshine/sunshine-monitor-setup.nix`, `nixos/modules/server/sunshine/sunshine-monitor-restore.nix` — define these as derivations within the feature or reference from sunshine feature. |
| **Host-specific data** | Current config reads `hostConfig.desktop.monitors`, `hostConfig.desktop.workspaceRules`, and uses `hostConfig.hostname == "workstation"` conditionals. **Approach:** Define `options.my.hyprland.monitors` and `options.my.hyprland.workspaceRules` as lists that host configurations set. For workstation-only scripts, either use `config.networking.hostName` conditional or make them separate features. |
| **Current dependencies** | Reads `desktop.lock` to determine lock command (hyprlock/swaylock/loginctl) — needs to detect which lock module is active. Options: (a) hardcode in host config, (b) define `options.my.desktop.lockCommand`. |
| **Standalone package** | If `wrapper-modules` supports hyprland, use that. Otherwise use `symlinkJoin` + `makeWrapper` with a generated config. |

#### Step 6.2 — `modules/features/niri.nix`

| Source | `nixos/modules/desktop/sessions/niri.nix` + `home/modules/desktop/sessions/niri.nix` |
|---|---|
| **Template** | C/D (Colocated + possible standalone) |
| **Module names** | `nixosModules.niri`, `homeModules.niri` |
| **NixOS side** | `programs.niri.enable`, PAM swaylock, polkit, wayland vars. Currently uses `unstable.niri` — reference `pkgs-unstable.niri` via specialArgs. |
| **HM side** | KDL config file symlinks (niri uses out-of-store symlinks to `niri-config/` directory), host-specific config file selection, packages (brightnessctl, pamixer, swaybg, xwayland-satellite). Also imports rofi — should reference `self.homeModules.rofi` or just import rofi at host level. |
| **Scripts to absorb** | `toggle-monitors-workstation-niri.nix`, `brightness-external.nix` (shared with hyprland — could be a shared feature). |
| **Host-specific data** | `hostConfig.hostname` selects config file. Define `options.my.niri.hostConfigFile` or use `config.networking.hostName` conditional. |
| **KDL config files** | The `home/modules/desktop/sessions/niri-config/` directory with .kdl files needs to be referenced. Copy these into `modules/features/niri-config/` alongside the feature. |

#### Step 6.3 — `modules/features/sway.nix`

| Source | `nixos/modules/desktop/sessions/sway.nix` + `home/modules/desktop/sessions/sway.nix` |
|---|---|
| **Template** | C (Colocated) |
| **Module names** | `nixosModules.sway`, `homeModules.sway` |
| **NixOS side** | `programs.sway.enable`, xdg-desktop-portal-wlr, PAM swaylock, polkit, wayland vars. |
| **HM side** | Full sway config (keybindings, output rules, window rules, startup). |
| **Scripts to absorb** | `toggle-monitors-workstation-sway.nix`. |

#### Step 6.4 — `modules/features/gnome.nix`

| Source | `nixos/modules/desktop/sessions/gnome.nix` + `home/modules/desktop/sessions/gnome.nix` |
|---|---|
| **Template** | C (Colocated) |
| **Module names** | `nixosModules.gnome`, `homeModules.gnome` |
| **NixOS side** | `services.xserver.enable`, `desktopManager.gnome.enable`, exclude gnome-tour + epiphany. |
| **HM side** | dconf settings (prefer-dark). Minimal. |

---

### Phase 7: Desktop Components

Each desktop component becomes a colocated feature. Most are HM-only with a thin NixOS wrapper for `sharedModules` injection.

#### Bars

| Step | Source | Feature name | Template | Standalone pkg? | Notes |
|---|---|---|---|---|---|
| 7.1 | `home/modules/desktop/bars/waybar.nix` | `waybar` | B2 + package | ✓ | Large config — session-aware (detects hyprland/niri/sway via `config.*.enable`). Uses `config.lib.stylix.colors`. Stylix must be active. |
| 7.2 | `home/modules/desktop/bars/hyprpanel.nix` | `hyprpanel` | B2 | ✗ | Uses `hostConfig.hostname` and `userSettings.stylixTheme` — replace with options or config introspection. |

#### Lock Screens

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 7.3 | `home/modules/desktop/lock/hyprlock.nix` | `hyprlock` | B2 | Tiny — just `programs.hyprlock.enable = true`. Stylix does the rest. |
| 7.4 | `home/modules/desktop/lock/swaylock.nix` | `swaylock` | B2 | Uses `config.lib.stylix.colors` for theming. |

#### Idle Daemons

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 7.5 | `home/modules/desktop/idle/hypridle.nix` | `hypridle` | B2 | Reads `desktop.lock` to determine lock command. **Replace with:** `options.my.idle.lockCommand` or detect which lock module is active. |
| 7.6 | `home/modules/desktop/idle/swayidle.nix` | `swayidle` | B2 | Same issue — reads `desktop.lock` and `desktop.session` for monitor power command (niri vs sway). |

#### Clipboard Managers

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 7.7 | `home/modules/desktop/clipboard/clipman.nix` | `clipman` | B2 | Uses `home/modules/desktop/lib.nix` helper `mkWlPasteWatchService` — inline the helper or define it within the feature. Also creates `clipboard-history` and `clipboard-clear` wrapper scripts. |
| 7.8 | `home/modules/desktop/clipboard/cliphist.nix` | `cliphist` | B2 | Same pattern as clipman. |

#### Screenshot Tools

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 7.9 | `home/modules/desktop/screenshot/grimblast.nix` | `grimblast` | B2 | Creates `screenshot` wrapper script. |
| 7.10 | `home/modules/desktop/screenshot/grim.nix` | `grimScreenshot` | B2 | Creates `screenshot` wrapper script (same name — can't have both active). |

#### Notification Daemons

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 7.11 | `home/modules/desktop/notifications/mako.nix` | `mako` | B2 | Small. Stylix handles theming. |
| 7.12 | `home/modules/desktop/notifications/dunst.nix` | `dunst` | B2 | Larger config with manual color settings. |

#### Other Desktop Components

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 7.13 | `home/modules/desktop/launchers/rofi.nix` + `rofi-theme.nix` | `rofi` | B2 + package | Merge both files. The `home/modules/desktop/rofi/default.nix` is an alternate rofi config — determine which one is actually used (likely the `launchers/` version). Uses `desktop.lock` for lock command + `config.lib.stylix.colors` for theme. |
| 7.14 | `home/modules/desktop/nightlight/gammastep.nix` | `gammastep` | B2 | Creates `nightlight-toggle` script. |
| 7.15 | `home/modules/desktop/nightlight/redshift.nix` | `redshift` | B2 | Creates `nightlight-toggle` script (same name — can't have both active). |
| 7.16 | `home/modules/desktop/logout/wlogout.nix` | `wlogout` | B2 | Minimal — just enable. |
| 7.17 | `home/modules/desktop/applets/wayland.nix` | `waylandApplets` | B2 | Network manager applet enable. |
| 7.18 | `home/modules/desktop/shells/noctalia/default.nix` | `noctalia` | B2 + package | Imports `inputs.noctalia.homeModules.default`. Reads JSON settings from `settings.json` file alongside. Copy the settings.json into feature directory or embed inline. |

#### Files to DELETE (no-op modules)

These "none" variant files are dispatcher artifacts. They contain empty modules (`{ ... }: {}`) and are no longer needed:

- `home/modules/desktop/launchers/none.nix` (note: this one imports rofi-theme.nix — rofi-theme should be absorbed into rofi.nix)
- `home/modules/desktop/idle/none.nix`
- `home/modules/desktop/lock/none.nix`
- `home/modules/desktop/lock/loginctl.nix`
- `home/modules/desktop/clipboard/none.nix`
- `home/modules/desktop/screenshot/none.nix`
- `home/modules/desktop/notifications/none.nix`
- `home/modules/desktop/nightlight/none.nix`
- `home/modules/desktop/applets/none.nix`
- `home/modules/desktop/logout/none.nix`

---

### Phase 8: Applications

All applications follow **Template B2** (homeModules + thin nixosModules wrapper) unless they warrant a standalone package. Most are simple — just `home.packages` or `programs.X.enable`.

#### Terminal Emulators (with standalone package)

| Step | Source | Feature name | Standalone? | Notes |
|---|---|---|---|---|
| 8.1 | `home/modules/applications/kitty.nix` | `kitty` | ✓ | Uses `config.stylix.fonts.*` for font config. Standalone package: `symlinkJoin` + `makeWrapper --config`. |

#### Text Editors

| Step | Source | Feature name | Standalone? | Notes |
|---|---|---|---|---|
| 8.2 | `home/modules/applications/nvf.nix` | `nvf` | ✓ | Complex — builds custom neovim with plugins (neocodeium, codecompanion) using `pkgs24-11.vimUtils.buildVimPlugin`. Uses `system`, `nvf`, `inputs`, `unstable`, `pkgs24-11` from specialArgs. Needs careful specialArgs migration. Standalone: expose as `perSystem.packages.nvim`. |
| 8.3 | `home/modules/applications/nvim.nix` | `nvim` | ✗ | Commented out in user imports. Migrate if desired. |

#### Shell & Terminal Tools

| Step | Source | Feature name | Standalone? | Notes |
|---|---|---|---|---|
| 8.4 | `home/modules/applications/zsh.nix` | `zsh` | ✓ | Large config: oh-my-zsh, aliases, fzf, zoxide, powerlevel10k. **Absorbs** `home/modules/scripts/search-with-zoxide.nix` (imported by zsh.nix). Standalone: wrap with custom zdotdir. |
| 8.5 | `home/modules/applications/tmux.nix` | `tmux` | ✓ | Vim-tmux-navigator integration. |
| 8.6 | `home/modules/applications/yazi.nix` | `yazi` | ✗ | File manager config. |

#### Browsers

| Step | Source | Feature name | Notes |
|---|---|---|---|
| 8.7 | `home/modules/applications/vivaldi.nix` | `vivaldi` | |
| 8.8 | `home/modules/applications/zen-browser.nix` | `zenBrowser` | Uses `zen-browser` input. |
| 8.9 | `home/modules/applications/brave.nix` | `brave` | Just `home.packages`. |
| 8.10 | `home/modules/applications/firefox.nix` | `firefox` | Just `programs.firefox.enable`. |
| 8.11 | `home/modules/applications/google-chrome.nix` | `googleChrome` | |
| 8.12 | `home/modules/applications/microsoft-edge.nix` | `microsoftEdge` | |

#### GUI Applications

| Step | Source | Feature name | Notes |
|---|---|---|---|
| 8.13 | `home/modules/applications/obsidian.nix` | `obsidian` | Uses `unstable.obsidian`. |
| 8.14 | `home/modules/applications/spotify.nix` | `spotify` | Just `home.packages`. |
| 8.15 | `home/modules/applications/gimp.nix` | `gimp` | |
| 8.16 | `home/modules/applications/gthumb.nix` | `gthumb` | |
| 8.17 | `home/modules/applications/mpv.nix` | `mpv` | Sets MIME associations. |
| 8.18 | `home/modules/applications/zathura.nix` | `zathura` | PDF viewer + MIME associations. |
| 8.19 | `home/modules/applications/libreoffice.nix` | `libreoffice` | |
| 8.20 | `home/modules/applications/nautilus.nix` | `nautilus` | |
| 8.21 | `home/modules/applications/mission-center.nix` | `missionCenter` | |
| 8.22 | `home/modules/applications/gnome-calculator.nix` | `gnomeCalculator` | |
| 8.23 | `home/modules/applications/vial.nix` | `vial` | Keyboard configurator. |

#### AI/Dev Tools (GUI)

| Step | Source | Feature name | Notes |
|---|---|---|---|
| 8.24 | `home/modules/applications/claude-code.nix` | `claudeCode` | Installed via npm. |
| 8.25 | `home/modules/applications/amazon-q.nix` | `amazonQ` | |
| 8.26 | `home/modules/applications/opencode/default.nix` | `opencode` | Complex — builds from local repo directory, copies config files. Has an `opencode/` subdirectory with config. Copy that directory to `modules/features/opencode-config/`. |
| 8.27 | `home/modules/applications/aider-chat.nix` | `aiderChat` | Currently commented out in user imports. |

#### Unused/Commented-out (migrate but mark optional)

| Source | Feature name | Notes |
|---|---|---|
| `home/modules/applications/vscode.nix` | `vscode` | Commented out in user imports. |
| `home/modules/applications/cursor.nix` | `cursor` | Commented out. |
| `home/modules/applications/qalculate.nix` | `qalculate` | Commented out. |
| `home/modules/applications/nsxiv.nix` | `nsxiv` | Commented out. |

---

### Phase 9: Settings & Environment

Features with user-specific data use **Template B** (options). Features without use **Template B2**.

#### Option-based features (user provides values)

| Step | Source | Feature name | Options to define | Notes |
|---|---|---|---|---|
| 9.1 | `home/modules/settings/git.nix` | `git` | `my.git.userName`, `my.git.userEmail` | Currently reads `userSettings.username/email`. Also includes SSH config (matchBlocks for github.com, hp-server). Consider splitting SSH matchBlocks into `sshConfig`. |
| 9.2 | `home/modules/settings/ssh.nix` | `sshConfig` | `my.ssh.serverHost`, `my.ssh.forwardPorts` | Port forwarding config for dev (Next.js, Supabase, etc.). Currently hardcoded — could use options or keep hardcoded per-user. |
| 9.3 | `home/modules/settings/secrets/secrets.nix` | `secrets` | None (file paths are relative) | Creates `~/.local/secrets/load-secrets.sh`. Copy `load-secrets.sh` script alongside the feature file. |

#### Non-option features (same for all users)

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 9.4 | `home/modules/settings/nerd-fonts.nix` | `nerdFonts` | B2 | Just `home.packages = [ nerd-fonts.hack ]`. |
| 9.5 | `home/modules/settings/udiskie.nix` | `udiskie` | B2 | Auto-mount service. Desktop-only. |
| 9.6 | `home/modules/environment/dev-tools.nix` | `devTools` | B2 | lazygit, jq, nodejs, rust, python, go, gcc, cmake + lazygit config. |
| 9.7 | `home/modules/environment/session-variables.nix` | `sessionVariables` | B2 | Editor (nvim), dev tool paths (NPM, cargo, Go, Python). |
| 9.8 | `home/modules/environment/direnv.nix` | `direnv` | B2 | `programs.direnv.enable + nix-direnv.enable`. |
| 9.9 | `home/modules/environment/bottles.nix` | `bottles` | B2 | Wine + Bottles for Windows apps. Desktop-only. |
| 9.10 | `home/modules/utils/default.nix` | `utils` | B2 | nix-search-tv, bat, fd, tree, btop, ripgrep, fzf + aliases. |

---

### Phase 10: Scripts & Utilities

| Step | Source | Feature name | Template | Notes |
|---|---|---|---|---|
| 10.1 | `home/modules/scripts/power-monitor.nix` | `powerMonitor` | B2 | Large bash script for power/performance monitoring. |
| 10.2 | `home/modules/scripts/yazi-float.nix` | `yaziFloat` | B2 | Wrapper script for yazi file manager. |
| 10.3 | `home/modules/scripts/search-with-zoxide.nix` | *(absorbed into zsh)* | — | Imported by `zsh.nix`, not standalone. |
| 10.4 | `home/modules/scripts/brightness-external.nix` | `brightnessExternal` | B2 | ddcutil wrapper for external monitor brightness. Shared by hyprland + niri. Make this its own feature that both WMs can depend on. |
| 10.5 | `home/modules/scripts/toggle-monitors-workstation-hyprland.nix` | *(absorbed into hyprland)* | — | Workstation-specific hyprland script. |
| 10.6 | `home/modules/scripts/toggle-monitors-workstation-niri.nix` | *(absorbed into niri)* | — | Workstation-specific niri script. |
| 10.7 | `home/modules/scripts/toggle-monitors-workstation-sway.nix` | *(absorbed into sway)* | — | Workstation-specific sway script. |

---

### Phase 11: Users

#### Step 11.1 — `modules/users/henhal.nix` (nixosModules.userHenhal)

| Source | `users/henhal/home.nix` + inline config from `lib/mk-nixos-system.nix` |
|---|---|
| **Template** | G (Slim user) |
| **Module name** | `nixosModules.userHenhal` |
| **System-level** | `users.users.henhal` (isNormalUser, groups, shell=zsh). Groups currently scattered across features (adbusers in android, etc.) — keep base groups here, feature-specific groups in features. |
| **HM identity** | `home.username`, `home.homeDirectory`, `home.stateVersion`, `programs.home-manager.enable`. |
| **Option values** | `my.git.userName/userEmail`, `my.theme.scheme/wallpaper`, `my.desktop.terminal/browser`. |
| **What NOT to include** | Feature imports (those go in host configuration.nix), application installs, desktop config. |
| **Boot-windows desktop entry** | Currently in `users/henhal/home.nix` — move to `bootWindows` feature (step 3.13). |

---

### Phase 12: Host Wiring

Fill in each host's `configuration.nix` with the correct feature imports. This is where everything comes together.

#### Step 12.1 — `hosts/workstation/hardware.nix`

| Source | `systems/workstation/hardware-configuration.nix` |
|---|---|
| **Module name** | `nixosModules.workstationHardware` |
| **What to include** | Auto-generated hardware config (initrd modules, fileSystems, swapDevices, nixpkgs.hostPlatform). Absorb NVIDIA-specific hardware from `systems/workstation/configuration.nix` (nvidia kernel modules, kernelParams, firmware). |

#### Step 12.2 — `hosts/workstation/configuration.nix`

| Source | `systems/workstation/configuration.nix` + `hosts/workstation.nix` (data) |
|---|---|
| **Module name** | `nixosModules.workstationConfig` |
| **Imports** | Every feature this host needs (see below) |

**Workstation feature imports:**
```
# Hardware & Core
workstationHardware, base, home-manager.nixosModules.home-manager

# Theme
stylix, inputs.stylix.nixosModules.stylix

# Boot & System
secureBoot, networking, pipewire, bluetooth, externalIo, printer, android, syncthing

# Graphics
nvidiaGraphics

# Desktop Session + Components
desktopCommon, hyprland, sddm, waybar, hyprlock, hypridle, rofi, clipman, grimblast, mako, wlogout, waylandApplets, gammastep

# Applications
kitty, vivaldi, zenBrowser, brave, googleChrome, microsoftEdge, firefox
zsh, tmux, yazi, obsidian, spotify, claudeCode, amazonQ, opencode, gimp, gthumb
mpv, zathura, libreoffice, nautilus, missionCenter, gnomeCalculator, vial, nvf

# Settings & Environment
git, sshConfig, secrets, nerdFonts, udiskie, devTools, direnv, sessionVariables, bottles, utils

# Scripts
powerMonitor, yaziFloat, brightnessExternal

# Server
sshServer, tailscale, sunshine

# Gaming
gaming, virtualization

# User
userHenhal
```

**Workstation-specific inline config:**
- `networking.hostName = "workstation"`
- `hardware.logitech.wireless.enable = true`
- `hardware.graphics.enable = true` + `enable32Bit`
- NVIDIA kernel params and initrd modules
- `security.pam.services.login.enableGnomeKeyring = true`
- `boot.kernel.sysctl."fs.inotify.max_user_watches"` increase
- `nixpkgs.config.allowUnfree = true`
- `home-manager` settings (useGlobalPkgs, extraSpecialArgs, etc.)

**Host-specific option values:**
```nix
# Set hyprland monitor config for workstation
my.hyprland.monitors = [
  "HDMI-A-1,1920x1080@144,0x0,1,transform,1"
  "DP-1,2560x1440@144,1080x0,1"
];
my.hyprland.workspaceRules = [
  "1, monitor:HDMI-A-1" "3, monitor:HDMI-A-1"
  "2, monitor:DP-1" "4, monitor:DP-1" "5, monitor:DP-1" "6, monitor:DP-1"
  "10, monitor:HEADLESS-1"
];
```

#### Step 12.3 — `hosts/lenovo-yoga-pro-7/hardware.nix`

| Source | `systems/lenovo-yoga-pro-7/hardware-configuration.nix` |
|---|---|
| **Module name** | `nixosModules.lenovoYogaPro7Hardware` |

#### Step 12.4 — `hosts/lenovo-yoga-pro-7/configuration.nix`

| Source | `systems/lenovo-yoga-pro-7/configuration.nix` + `hosts/lenovo-yoga-pro-7.nix` (data) |
|---|---|
| **Module name** | `nixosModules.lenovoYogaPro7Config` |

**Laptop feature imports (differences from workstation):**
- **Uses `niri` instead of `hyprland`**
- **Uses `noctalia` instead of waybar + mako + wlogout** (noctalia handles all three)
- **Uses `swaylock` + `swayidle`** instead of hyprlock + hypridle
- **Uses `amdGraphics` instead of `nvidiaGraphics`**
- **Uses `minimalBattery`** (laptop power management)
- **Uses `systemdLogind`** (lid switch behavior)
- **Uses `bootloader`** (not secureBoot)
- **No `gaming`, `sunshine`**, `bootWindows`
- **Has `grim-screenshot`** instead of `grimblast`
- **Has `logitech` wireless** enabled

#### Step 12.5 — `hosts/hp-server/hardware.nix`

| Source | `systems/hp-server/hardware-configuration.nix` |
|---|---|
| **Module name** | `nixosModules.hpServerHardware` |
| **Notes** | Also absorb `systems/hp-server/bootloader.nix` (GRUB config — currently all commented out, uses default bootloader). |

#### Step 12.6 — `hosts/hp-server/configuration.nix`

| Source | `systems/hp-server/configuration.nix` + `hosts/hp-server.nix` (data) |
|---|---|
| **Module name** | `nixosModules.hpServerConfig` |

**Server feature imports (minimal — no desktop):**
```
# Hardware & Core
hpServerHardware, base, home-manager.nixosModules.home-manager, bootloader, networking

# System
pipewire, bluetooth, nvidiaGraphics

# Server
serverBase, sshServer, tailscale, serverMonitoring, laptopServer
inputs.vscode-server.nixosModules.default (+ enable)

# CLI apps only (no desktop features)
zsh, yazi, tmux, nvf, git, sshConfig, secrets, nerdFonts, devTools, direnv, sessionVariables, utils

# User
userHenhal
```

---

### Phase 13: Dev Shells

| Step | Source | Feature name | Notes |
|---|---|---|---|
| 13.1 | `shells/rust/flake.nix` | `modules/dev-shells/rust.nix` | Define `perSystem.devShells.rust`. Extract the shell definition from the standalone flake. |
| 13.2 | `shells/js/react-native/flake.nix` | `modules/dev-shells/react-native.nix` | Define `perSystem.devShells.react-native`. The standalone flake (`flake-standalone.nix`) can remain for use outside this repo. |
| 13.3 | `shells/sandboxes/catchall-sandbox.nix` | `modules/dev-shells/sandbox.nix` | If it's a dev shell, define as `perSystem.devShells.sandbox`. |

---

### Phase 14: Nix-on-Droid

| Source | `nix-on-droid/default.nix` + `users/henhal-android/home.nix` |
|---|---|
| **Target** | `modules/nix-on-droid.nix` + `modules/users/henhal-android.nix` |
| **Approach** | Define `flake.nixOnDroidConfigurations.default` in a flake-parts module. The home-manager config for the android user can import `self.homeModules.*` for shared modules (zsh, yazi, nvf, git, devTools, direnv, utils, nerdFonts). Android-specific modules (`nix-on-droid/modules/basic-cli-tools.nix`, `ssh-client.nix`) and theme (`nix-on-droid/theme.nix`) stay as local imports or become their own homeModules. |
| **Shared modules** | `self.homeModules.zsh`, `self.homeModules.yazi`, `self.homeModules.nvf`, `self.homeModules.git`, `self.homeModules.devTools`, `self.homeModules.direnv`, `self.homeModules.utils`, `self.homeModules.nerdFonts`, `self.homeModules.sessionVariables` |
| **Android-only** | Termux config, Nerd Font copying activation, hostname override, p10k-android config. These stay in the user module or become `homeModules.androidTermux`. |

---

### Phase 15: Validation & Cleanup

#### Build all hosts
```bash
nix build .#nixosConfigurations.workstation.config.system.build.toplevel
nix build .#nixosConfigurations.lenovo-yoga-pro-7.config.system.build.toplevel
nix build .#nixosConfigurations.hp-server.config.system.build.toplevel
```

#### Test standalone packages
```bash
nix run .#kitty
nix run .#nvim
nix run .#zsh
```

#### Test dev shells
```bash
nix develop .#rust
nix develop .#react-native
```

#### Delete old config directories
- `hosts/*.nix` (old flat host data files — NOT the `hosts/` directories we created)
- `systems/`
- `nixos/`
- `home/`
- `lib/`
- `users/`
- `shells/`
- `nix-on-droid/` (if fully absorbed)

#### Move new-config to root
```bash
# After validation, move new-config contents to repo root
cp -r new-config/* .
rm -rf new-config/
```

#### Update documentation
- `README.md`
- `docs/DESKTOP_CONFIGURATION.md` (may be obsolete — the pattern is self-documenting)
- `scripts/install.sh`

---

## Complete File Mapping

### Files to DELETE (dispatcher/factory infrastructure)

| File | Reason |
|---|---|
| `lib/mk-nixos-system.nix` | Replaced by per-host `default.nix` entry points |
| `lib/desktop.nix` | Dispatcher eliminated — hosts explicitly import features |
| `lib/theme.nix` | Absorbed into `modules/features/stylix.nix` |
| `nixos/default.nix` | Absorbed into `modules/base.nix` |
| `nixos/modules/desktop/default.nix` | NixOS dispatcher eliminated |
| `home/modules/desktop/default.nix` | Home dispatcher eliminated |
| `home/modules/desktop/lib.nix` | `mkWlPasteWatchService` helper inlined into clipboard features |
| `home/modules/desktop/*/none.nix` (×10) | No-op modules — not needed when features are explicit |
| `home/modules/desktop/lock/loginctl.nix` | No-op — loginctl is just a command |
| `home/modules/desktop/rofi/default.nix` | Alternate rofi config — determine if used, merge into `rofi.nix` |
| `systems/desktop/` | Legacy host — already marked for deletion |

### Host files (restructured)

| Old file(s) | New file | What happens |
|---|---|---|
| `hosts/workstation.nix` (data) | — | Data inlined into `hosts/workstation/configuration.nix` as option values |
| `hosts/lenovo-yoga-pro-7.nix` (data) | — | Data inlined into `hosts/lenovo-yoga-pro-7/configuration.nix` |
| `hosts/hp-server.nix` (data) | — | Data inlined into `hosts/hp-server/configuration.nix` |
| `systems/workstation/hardware-configuration.nix` | `hosts/workstation/hardware.nix` | Wrapped in flake-parts boilerplate |
| `systems/workstation/configuration.nix` | `hosts/workstation/configuration.nix` | Feature imports + host-specific config |
| `systems/workstation/secure-boot.nix` | `modules/features/secure-boot.nix` | Becomes standalone feature |
| `systems/workstation/scripts/boot-windows.nix` | `modules/features/boot-windows.nix` | Becomes colocated feature (NixOS + HM desktop entry) |
| `systems/lenovo-yoga-pro-7/hardware-configuration.nix` | `hosts/lenovo-yoga-pro-7/hardware.nix` | Wrapped in flake-parts boilerplate |
| `systems/lenovo-yoga-pro-7/configuration.nix` | `hosts/lenovo-yoga-pro-7/configuration.nix` | Feature imports + host-specific config |
| `systems/lenovo-yoga-pro-7/amd-graphics.nix` | `modules/features/amd-graphics.nix` | Becomes standalone feature |
| `systems/lenovo-yoga-pro-7/battery.nix` | — | Unused (minimal-battery.nix is used instead) |
| `systems/lenovo-yoga-pro-7/minimal-battery.nix` | `modules/features/minimal-battery.nix` | Becomes standalone feature |
| `systems/hp-server/hardware-configuration.nix` | `hosts/hp-server/hardware.nix` | Wrapped in flake-parts boilerplate |
| `systems/hp-server/configuration.nix` | `hosts/hp-server/configuration.nix` | Feature imports + host-specific config |
| `systems/hp-server/bootloader.nix` | — | Mostly commented out — use default bootloader feature |
| `systems/hp-server/laptop-server.nix` | `modules/features/laptop-server.nix` | Becomes standalone feature |
| `systems/desktop/*` | — | **Deleted** — legacy |
| *(new)* | `hosts/*/default.nix` | Entry points defining `nixosConfigurations.*` |

### NixOS modules → Features

| Old file | Feature name | Template | Colocated with |
|---|---|---|---|
| `nixos/modules/bluetooth.nix` | `bluetooth` | A | — |
| `nixos/modules/pipewire.nix` | `pipewire` | A | — |
| `nixos/modules/networking.nix` | `networking` | A | — |
| `nixos/modules/bootloader.nix` | `bootloader` | A | — |
| `nixos/modules/external-io.nix` | `externalIo` | A | — |
| `nixos/modules/printer.nix` | `printer` | A | — |
| `nixos/modules/android.nix` | `android` | A | — |
| `nixos/modules/systemd-loginhd.nix` | `systemdLogind` | A | — |
| `nixos/modules/nvidia-graphics.nix` | `nvidiaGraphics` | A | — |
| `nixos/modules/gaming.nix` | `gaming` | A | — |
| `nixos/modules/virtualization.nix` | `virtualization` | A | — |
| `nixos/modules/syncthing.nix` | `syncthing` | A | — |
| `nixos/modules/desktop/common.nix` | `desktopCommon` | C | `home/modules/desktop/common.nix` |
| `nixos/modules/desktop/sessions/hyprland.nix` | `hyprland` | C/D | `home/modules/desktop/sessions/hyprland.nix` |
| `nixos/modules/desktop/sessions/niri.nix` | `niri` | C/D | `home/modules/desktop/sessions/niri.nix` |
| `nixos/modules/desktop/sessions/sway.nix` | `sway` | C | `home/modules/desktop/sessions/sway.nix` |
| `nixos/modules/desktop/sessions/gnome.nix` | `gnome` | C | `home/modules/desktop/sessions/gnome.nix` |
| `nixos/modules/desktop/display-managers/sddm.nix` | `sddm` | A | — |
| `nixos/modules/desktop/display-managers/gdm.nix` | `gdm` | A | — |
| `nixos/modules/server/default.nix` | `serverBase` | A | — |
| `nixos/modules/server/ssh.nix` | `sshServer` | A | — |
| `nixos/modules/server/tailscale.nix` | `tailscale` | A | — |
| `nixos/modules/server/server-monitoring.nix` | `serverMonitoring` | A | — |
| `nixos/modules/server/sunshine/default.nix` | `sunshine` | A | — |
| `nixos/modules/server/cockpit.nix` | `cockpit` | A | — |
| `nixos/modules/theme/stylix.nix` | `stylix` | C | `home/modules/themes/stylix/default.nix` + `lib/theme.nix` |

### Home-manager modules → Features

| Old file | Feature name | Template | Colocated with | Standalone pkg? |
|---|---|---|---|---|
| `home/modules/desktop/sessions/hyprland.nix` | `hyprland` | C/D | NixOS hyprland | Possible |
| `home/modules/desktop/sessions/niri.nix` | `niri` | C/D | NixOS niri | Possible |
| `home/modules/desktop/sessions/sway.nix` | `sway` | C | NixOS sway | ✗ |
| `home/modules/desktop/sessions/gnome.nix` | `gnome` | C | NixOS gnome | ✗ |
| `home/modules/desktop/bars/waybar.nix` | `waybar` | B2 | — | ✓ |
| `home/modules/desktop/bars/hyprpanel.nix` | `hyprpanel` | B2 | — | ✗ |
| `home/modules/desktop/lock/hyprlock.nix` | `hyprlock` | B2 | — | ✗ |
| `home/modules/desktop/lock/swaylock.nix` | `swaylock` | B2 | — | ✗ |
| `home/modules/desktop/idle/hypridle.nix` | `hypridle` | B2 | — | ✗ |
| `home/modules/desktop/idle/swayidle.nix` | `swayidle` | B2 | — | ✗ |
| `home/modules/desktop/launchers/rofi.nix` + `rofi-theme.nix` | `rofi` | B2 | — | ✓ |
| `home/modules/desktop/clipboard/clipman.nix` | `clipman` | B2 | — | ✗ |
| `home/modules/desktop/clipboard/cliphist.nix` | `cliphist` | B2 | — | ✗ |
| `home/modules/desktop/screenshot/grimblast.nix` | `grimblast` | B2 | — | ✗ |
| `home/modules/desktop/screenshot/grim.nix` | `grimScreenshot` | B2 | — | ✗ |
| `home/modules/desktop/notifications/mako.nix` | `mako` | B2 | — | ✗ |
| `home/modules/desktop/notifications/dunst.nix` | `dunst` | B2 | — | ✗ |
| `home/modules/desktop/nightlight/gammastep.nix` | `gammastep` | B2 | — | ✗ |
| `home/modules/desktop/nightlight/redshift.nix` | `redshift` | B2 | — | ✗ |
| `home/modules/desktop/logout/wlogout.nix` | `wlogout` | B2 | — | ✗ |
| `home/modules/desktop/applets/wayland.nix` | `waylandApplets` | B2 | — | ✗ |
| `home/modules/desktop/shells/noctalia/default.nix` | `noctalia` | B2 | — | ✓ |
| `home/modules/desktop/common.nix` | `desktopCommon` | C | NixOS desktop/common.nix | ✗ |
| `home/modules/applications/kitty.nix` | `kitty` | B2 | — | ✓ |
| `home/modules/applications/zsh.nix` | `zsh` | B2 | — | ✓ |
| `home/modules/applications/nvf.nix` | `nvf` | B2 | — | ✓ |
| `home/modules/applications/tmux.nix` | `tmux` | B2 | — | ✓ |
| `home/modules/applications/yazi.nix` | `yazi` | B2 | — | ✗ |
| `home/modules/applications/vivaldi.nix` | `vivaldi` | B2 | — | ✗ |
| `home/modules/applications/zen-browser.nix` | `zenBrowser` | B2 | — | ✗ |
| `home/modules/applications/brave.nix` | `brave` | B2 | — | ✗ |
| `home/modules/applications/firefox.nix` | `firefox` | B2 | — | ✗ |
| `home/modules/applications/google-chrome.nix` | `googleChrome` | B2 | — | ✗ |
| `home/modules/applications/microsoft-edge.nix` | `microsoftEdge` | B2 | — | ✗ |
| `home/modules/applications/obsidian.nix` | `obsidian` | B2 | — | ✗ |
| `home/modules/applications/spotify.nix` | `spotify` | B2 | — | ✗ |
| `home/modules/applications/gimp.nix` | `gimp` | B2 | — | ✗ |
| `home/modules/applications/gthumb.nix` | `gthumb` | B2 | — | ✗ |
| `home/modules/applications/mpv.nix` | `mpv` | B2 | — | ✗ |
| `home/modules/applications/zathura.nix` | `zathura` | B2 | — | ✗ |
| `home/modules/applications/libreoffice.nix` | `libreoffice` | B2 | — | ✗ |
| `home/modules/applications/nautilus.nix` | `nautilus` | B2 | — | ✗ |
| `home/modules/applications/mission-center.nix` | `missionCenter` | B2 | — | ✗ |
| `home/modules/applications/gnome-calculator.nix` | `gnomeCalculator` | B2 | — | ✗ |
| `home/modules/applications/vial.nix` | `vial` | B2 | — | ✗ |
| `home/modules/applications/claude-code.nix` | `claudeCode` | B2 | — | ✗ |
| `home/modules/applications/amazon-q.nix` | `amazonQ` | B2 | — | ✗ |
| `home/modules/applications/opencode/default.nix` | `opencode` | B2 | — | ✗ |
| `home/modules/applications/aider-chat.nix` | `aiderChat` | B2 | — | ✗ |
| `home/modules/applications/vscode.nix` | `vscode` | B2 | — | ✗ |
| `home/modules/applications/cursor.nix` | `cursor` | B2 | — | ✗ |
| `home/modules/applications/qalculate.nix` | `qalculate` | B2 | — | ✗ |
| `home/modules/applications/nsxiv.nix` | `nsxiv` | B2 | — | ✗ |
| `home/modules/settings/git.nix` | `git` | B | — | ✗ |
| `home/modules/settings/ssh.nix` | `sshConfig` | B | — | ✗ |
| `home/modules/settings/secrets/secrets.nix` | `secrets` | B2 | — | ✗ |
| `home/modules/settings/nerd-fonts.nix` | `nerdFonts` | B2 | — | ✗ |
| `home/modules/settings/udiskie.nix` | `udiskie` | B2 | — | ✗ |
| `home/modules/environment/dev-tools.nix` | `devTools` | B2 | — | ✗ |
| `home/modules/environment/session-variables.nix` | `sessionVariables` | B2 | — | ✗ |
| `home/modules/environment/direnv.nix` | `direnv` | B2 | — | ✗ |
| `home/modules/environment/bottles.nix` | `bottles` | B2 | — | ✗ |
| `home/modules/utils/default.nix` | `utils` | B2 | — | ✗ |
| `home/modules/scripts/power-monitor.nix` | `powerMonitor` | B2 | — | ✗ |
| `home/modules/scripts/yazi-float.nix` | `yaziFloat` | B2 | — | ✗ |
| `home/modules/scripts/brightness-external.nix` | `brightnessExternal` | B2 | — | ✗ |
| `home/modules/scripts/search-with-zoxide.nix` | *(absorbed into zsh)* | — | — | ✗ |
| `home/modules/scripts/toggle-monitors-*` (×3) | *(absorbed into WMs)* | — | — | ✗ |
| `home/modules/themes/stylix/default.nix` | `stylix` | C | NixOS stylix | ✗ |
| `home/modules/themes/catppuccin/default.nix` | `catppuccin` | B2 | — | ✗ |

### Users

| Old file | New file | Notes |
|---|---|---|
| `users/henhal/home.nix` | `modules/users/henhal.nix` | Slim: identity + `my.*` option values only |
| `users/henhal-android/home.nix` | `modules/users/henhal-android.nix` or `modules/nix-on-droid.nix` | Android-specific HM config |

### Other

| Old file | New file | Notes |
|---|---|---|
| `shells/rust/flake.nix` | `modules/dev-shells/rust.nix` | `perSystem.devShells.rust` |
| `shells/js/react-native/flake.nix` | `modules/dev-shells/react-native.nix` | `perSystem.devShells.react-native` |
| `shells/js/react-native/flake-standalone.nix` | — | Keep as standalone flake |
| `shells/sandboxes/catchall-sandbox.nix` | `modules/dev-shells/sandbox.nix` | `perSystem.devShells.sandbox` |
| `nix-on-droid/default.nix` | `modules/nix-on-droid.nix` | `flake.nixOnDroidConfigurations.default` |
| `nix-on-droid/modules/*.nix` | `modules/nix-on-droid.nix` or `homeModules.*` | Determine if reusable |
| `nix-on-droid/theme.nix` | `modules/nix-on-droid.nix` | Terminal color definitions |
| `flake.nix` (root) | `flake.nix` (rewritten) | mkFlake + import-tree |

---

## specialArgs Migration

The current config passes many custom values through `specialArgs`. These need to be eliminated or replaced.

| Current specialArg | Used by | Migration approach |
|---|---|---|
| `userSettings` | Many files | **Eliminated.** User identity → user module. `userSettings.term/browser` → `options.my.desktop.*`. `userSettings.username` → `config.users.users` introspection or hardcode. `userSettings.stylixTheme` → `options.my.theme.*`. `userSettings.stateVersion` → inline per-host. |
| `hostConfig` | WM sessions, hyprpanel, desktop dispatchers | **Eliminated.** Monitor/workspace data → `options.my.hyprland.*`, `options.my.niri.*`. GPU/hardware → features decide themselves. Hostname conditionals → `config.networking.hostName`. |
| `desktop` | Desktop dispatchers, idle, lock, rofi | **Eliminated.** The resolver + dispatcher is gone. Each feature is explicit. Cross-feature references (e.g., idle needing lock command) use `options.my.desktop.lockCommand` or detect via `config.programs.*.enable`. |
| `unstable` / `pkgs-unstable` | nvf, obsidian, niri, hyprpanel | **Replaced** with `pkgs-unstable` passed via `specialArgs` from host `default.nix`. |
| `pkgs24-11` | nvf (plugin builds) | **Replaced** with `pkgs-24-11` via `specialArgs`. |
| `inputs` | nvf, noctalia, zen-browser, stylix | **Kept.** Pass `inputs` via `specialArgs` in host `default.nix`. |
| `self` | Feature cross-referencing | **Kept.** Passed as top-level flake-parts arg. Features use `self.nixosModules.*`, `self.homeModules.*`, `self'.packages.*`. |
| `hostname` / `systemName` | networking, various | **Eliminated.** Use `config.networking.hostName`. |
| `windowManager` | Legacy compatibility | **Eliminated.** |
| `zen-browser` / `nvf` / `nvim-nix` / `stylix` | Specific features | **Folded into `inputs`** — already there, just use `inputs.zen-browser`, etc. |

---

## Risks & Open Questions

### Risks

1. **`home-manager.sharedModules` applies globally** — Every `nixosModules.X` that injects a `homeModules.X` applies it to ALL users on that machine. Fine for single-user (this config); needs rethinking for multi-user.

2. **Module name collisions** — `import-tree` loads everything. Two files defining `flake.nixosModules.hyprland` will conflict. Names must be globally unique. Use the feature name mapping above consistently.

3. **`specialArgs` propagation** — Home-manager modules injected via `sharedModules` don't automatically get NixOS `specialArgs`. Use `home-manager.extraSpecialArgs` in the host to pass through `inputs`, `self`, `pkgs-unstable`, etc.

4. **`wrapper-modules` availability** — Not all programs have wrappers. Check [BirdeeHub/nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules) before planning which programs to wrap. For unsupported programs, use `symlinkJoin` + `makeWrapper`.

5. **Option namespace collisions** — Features define options under `my.*` (e.g., `my.git.userName`). This namespace must not collide with other NixOS/HM options. Using a unique prefix like `my.*` or `dotfiles.*` avoids this.

6. **Stylix dependency ordering** — Many features reference `config.lib.stylix.colors` or `config.stylix.fonts.*`. The `inputs.stylix.nixosModules.stylix` must be imported before these features evaluate. In practice, NixOS module system handles this via lazy evaluation, but test early.

7. **Niri KDL config files** — Niri uses KDL config files with out-of-store symlinks. The `niri-config/` directory needs to be accessible from the new location. Either copy the directory alongside the feature file or use absolute paths.

### Open Questions

1. **Bundle modules vs. explicit imports?** — Should each host list every feature individually, or use bundle modules (e.g., `bundleDesktopHyprland`)? Start explicit, add bundles later if the import lists get unwieldy.

2. **Cross-feature dependencies (idle ↔ lock)** — The idle daemon needs to know the lock command. Options: (a) `options.my.desktop.lockCommand` set by host, (b) idle feature detects which lock is active via `config.programs.hyprlock.enable`, (c) just hardcode in the host. Approach (b) is most elegant.

3. **Host-specific scripts in WMs** — Toggle-monitors scripts are workstation-only. Options: (a) `config.networking.hostName == "workstation"` conditional inside the WM feature, (b) separate `toggleMonitors` feature only imported by workstation, (c) options `my.hyprland.extraScripts`. Start with (a), refactor later.

4. **Noctalia all-in-one shell** — When using Noctalia, the host simply doesn't import waybar + mako + wlogout. The conflict resolution is now implicit — solved by explicit feature selection per host.

5. **`home/modules/desktop/rofi/default.nix` vs `home/modules/desktop/launchers/rofi.nix`** — Two rofi configs exist. Determine which is actually used in the active config and migrate only that one. The other can be deleted.

6. **catppuccin theme** — Currently commented out (stylix is used). Migrate for completeness or delete?
