# Desktop Configuration System

This document describes the modular desktop configuration system for NixOS + Home Manager. It allows per-host selection of desktop sessions, bars, lock screens, and idle daemons with full theming integration.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Directory Structure](#directory-structure)
4. [Quick Start](#quick-start)
5. [Host Configuration Reference](#host-configuration-reference)
6. [User Configuration Reference](#user-configuration-reference)
7. [Adding a New Host](#adding-a-new-host)
8. [Modifying an Existing Host](#modifying-an-existing-host)
9. [Component Reference](#component-reference)
10. [Theming](#theming)
11. [Examples](#examples)
12. [Troubleshooting](#troubleshooting)

---

## Overview

### Design Principles

1. **Pure data in `hosts/`** - Host files contain only data (attrsets), no imports or modules
2. **Modules consume data** - NixOS and Home Manager modules read host data and apply logic
3. **Lookup tables over conditionals** - No scattered if/else chains
4. **Defaults with overrides** - Sensible defaults; only specify what differs
5. **Single source of truth** - Each setting defined in exactly one place

### What You Can Configure Per Host

| Component | Options | Default |
|-----------|---------|---------|
| Session | `hyprland`, `sway`, `gnome`, `none` | `none` |
| Status Bar | `hyprpanel`, `waybar`, `none` | Per-session |
| Lock Screen | `hyprlock`, `swaylock`, `loginctl` | Per-session |
| Idle Daemon | `hypridle`, `swayidle`, `none` | Per-session |
| Display Manager | `sddm`, `gdm`, `none` | Per-session |
| Monitors | List of monitor configs | Auto-detect |
| Workspaces | Workspace-to-monitor mapping | Default |

---

## Architecture

### Data Flow

```
hosts/<hostname>.nix (pure data)
         │
         ▼
    flake.nix
    imports host, creates nixosConfiguration
         │
         ▼
lib/mk-nixos-system.nix
  ├── Imports host config
  ├── Resolves null values to session defaults (lib/desktop.nix)
  ├── Passes resolved `desktop` + `hostConfig` via specialArgs
         │
         ├────────────────────────────────┐
         ▼                                ▼
┌─────────────────────┐      ┌─────────────────────────┐
│ NixOS Modules       │      │ Home Manager Modules    │
│                     │      │                         │
│ desktop/default.nix │      │ desktop/default.nix     │
│  ├── common.nix     │      │  ├── common.nix         │
│  ├── sessions/*     │      │  ├── sessions/*         │
│  └── display-mgrs/* │      │  ├── bars/*             │
│                     │      │  ├── lock/*             │
│ theme/stylix.nix    │      │  ├── idle/*             │
│                     │      │  └── launchers/*        │
└─────────────────────┘      └─────────────────────────┘
```

### Key Concepts

- **hostConfig**: The raw data from `hosts/<hostname>.nix`
- **desktop**: Pre-resolved desktop settings (nulls replaced with defaults)
- **userSettings**: User-specific settings (username, terminal, browser, theme)

---

## Directory Structure

```
.
├── flake.nix                        # Entry point, defines nixosConfigurations
│
├── hosts/                           # Pure data files (NO imports)
│   ├── workstation.nix              # Desktop PC config
│   ├── lenovo-yoga-pro-7.nix        # Laptop config
│   └── hp-server.nix                # Server (no desktop)
│
├── lib/                             # Shared functions
│   ├── desktop.nix                  # Desktop defaults & resolver
│   ├── theme.nix                    # Stylix theme config
│   └── mk-nixos-system.nix          # System builder
│
├── systems/                         # NixOS per-host modules
│   ├── workstation/
│   │   ├── configuration.nix        # Hardware, services
│   │   └── hardware-configuration.nix
│   └── ...
│
├── nixos/modules/                   # Shared NixOS modules
│   ├── desktop/
│   │   ├── default.nix              # Dispatcher
│   │   ├── common.nix               # Shared config
│   │   ├── sessions/                # hyprland.nix, sway.nix, gnome.nix
│   │   └── display-managers/        # sddm.nix, gdm.nix
│   └── theme/
│       └── stylix.nix
│
├── home/modules/                    # Shared Home Manager modules
│   ├── desktop/
│   │   ├── default.nix              # Dispatcher
│   │   ├── common.nix               # Shared packages
│   │   ├── sessions/                # hyprland.nix, sway.nix, gnome.nix
│   │   ├── bars/                    # waybar.nix, hyprpanel.nix
│   │   ├── lock/                    # hyprlock.nix, swaylock.nix
│   │   ├── idle/                    # hypridle.nix, swayidle.nix
│   │   └── launchers/               # rofi.nix
│   └── themes/stylix/
│
├── users/                           # Per-user Home Manager config
│   └── henhal/
│       └── home.nix
│
└── assets/
    ├── wallpapers/                  # Wallpaper images
    └── themes/                      # Custom themes (if any)
```

---

## Quick Start

### Minimal Host Setup

1. Create a host file:

```nix
# hosts/my-pc.nix
{
  hostname = "my-pc";

  desktop = {
    session = "hyprland";
  };

  hardware = {};
}
```

2. Add to flake.nix:

```nix
nixosConfigurations = {
  my-pc = mkSystem {
    hostConfig = hosts.my-pc;
    userSettings = users.henhal;
  };
};
```

3. Build and switch:

```bash
sudo nixos-rebuild switch --flake .#my-pc
```

That's it! The system will use session defaults for bar, lock, idle, and display manager.

---

## Host Configuration Reference

Host files live in `hosts/` and contain pure data (no imports, no `lib`, no `pkgs`).

### Full Schema

```nix
# hosts/<hostname>.nix
{
  # Required
  hostname = "my-hostname";          # Network hostname

  # Desktop configuration
  desktop = {
    # Required if you want a desktop
    session = "hyprland";            # "hyprland" | "sway" | "gnome" | "none"

    # Optional - null uses session defaults
    bar = null;                      # "hyprpanel" | "waybar" | "none" | null
    lock = null;                     # "hyprlock" | "swaylock" | "loginctl" | null
    idle = null;                     # "hypridle" | "swayidle" | "none" | null

    # Session-specific: Hyprland
    monitors = [                     # Monitor configuration
      "DP-1,3440x1440@144,0x0,1"     # name,resolution@rate,position,scale
      "DP-2,2560x1440@144,3440x0,1"
    ];

    workspaceRules = [               # Workspace assignments
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-1"
      "4, monitor:DP-2, default:true"
    ];

    # Session-specific: Sway
    outputs = {                      # Sway output config
      "eDP-1" = {
        resolution = "2880x1800@120Hz";
        scale = 1.5;
        position = "0,0";
      };
    };

    # Extra session config (raw config string)
    extraConfig = ''
      # Additional hyprland/sway config
    '';

    # Component-specific overrides
    hyprpanel = {                    # Hyprpanel settings
      bar.position = "top";
    };
  };

  # Hardware flags (used by systems/<hostname>/configuration.nix)
  hardware = {
    gpu = "nvidia";                  # "nvidia" | "amd" | "intel"
    logitech = true;                 # Enable Logitech wireless
    bluetooth = true;                # Enable Bluetooth
  };
}
```

### Per-Session Defaults

When you set `bar`, `lock`, or `idle` to `null`, these defaults apply:

| Session | Bar | Lock | Idle | Display Manager |
|---------|-----|------|------|-----------------|
| `hyprland` | hyprpanel | hyprlock | hypridle | sddm |
| `sway` | waybar | swaylock | swayidle | sddm |
| `gnome` | none | loginctl | none | gdm |
| `none` | none | none | none | none |

### Monitor Configuration

#### Hyprland Format

```
name,resolution@refreshrate,position,scale
```

Examples:
```nix
monitors = [
  # Single monitor, auto-detect
  ",preferred,auto,1"

  # Specific monitor at position 0,0
  "DP-1,3440x1440@144,0x0,1"

  # Second monitor to the right, scaled
  "DP-2,2560x1440@144,3440x0,1"

  # Laptop display with HiDPI
  "eDP-1,2880x1800@120,0x0,1.5"

  # Disable a monitor
  "HDMI-A-1,disable"
];
```

#### Sway Format

```nix
outputs = {
  "eDP-1" = {
    resolution = "2880x1800@120Hz";
    scale = 1.5;
    position = "0,0";
  };
  "DP-1" = {
    resolution = "3440x1440@144Hz";
    position = "2880,0";
  };
};
```

### Workspace Rules (Hyprland)

```nix
workspaceRules = [
  "1, monitor:DP-1, default:true"    # Workspace 1 on DP-1, default
  "2, monitor:DP-1"                  # Workspace 2 on DP-1
  "3, monitor:DP-1"
  "4, monitor:DP-2, default:true"    # Workspace 4 on DP-2, default
  "5, monitor:DP-2"
];
```

---

## User Configuration Reference

User settings are defined in `flake.nix`:

```nix
users = {
  henhal = {
    # Required
    username = "henhal";
    name = "Henrik";
    email = "henhalvor@gmail.com";
    homeDirectory = "/home/henhal";
    stateVersion = "25.05";

    # Applications
    term = "kitty";                  # Terminal emulator
    browser = "vivaldi";             # Default browser

    # Theming
    stylixTheme = {
      scheme = "gruvbox-dark-hard";  # Base16 scheme name
      wallpaper = "starry-sky.png";  # Filename in assets/wallpapers/
    };
  };
};
```

### Available Themes

Themes are base16 schemes from `pkgs.base16-schemes`:

| Scheme Name | Description |
|-------------|-------------|
| `catppuccin-mocha` | Catppuccin Mocha (dark) |
| `catppuccin-macchiato` | Catppuccin Macchiato (dark) |
| `gruvbox-dark-hard` | Gruvbox Dark Hard |
| `gruvbox-dark-medium` | Gruvbox Dark Medium |
| `nord` | Nord |
| `dracula` | Dracula |
| `rose-pine-moon` | Rosé Pine Moon |
| `tokyo-night-dark` | Tokyo Night Dark |
| `one-dark` | One Dark |

Add more in `lib/theme.nix` by extending the `schemes` attrset.

---

## Adding a New Host

### Step 1: Create Host Data File

```nix
# hosts/my-new-pc.nix
{
  hostname = "my-new-pc";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";
    # lock and idle will use hyprland defaults

    monitors = [
      "DP-1,1920x1080@60,0x0,1"
    ];
  };

  hardware = {
    gpu = "nvidia";
  };
}
```

### Step 2: Create System Configuration

```bash
mkdir -p systems/my-new-pc
```

```nix
# systems/my-new-pc/configuration.nix
{ config, pkgs, desktop, hostConfig, userSettings, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/default.nix
  ];

  # GPU configuration based on hostConfig
  services.xserver.videoDrivers =
    lib.mkIf (hostConfig.hardware.gpu or "" == "nvidia") [ "nvidia" ];

  # Add host-specific hardware config here
}
```

Generate hardware config:
```bash
sudo nixos-generate-config --show-hardware-config > systems/my-new-pc/hardware-configuration.nix
```

### Step 3: Add to flake.nix

```nix
let
  hosts = {
    # ... existing hosts
    my-new-pc = import ./hosts/my-new-pc.nix;
  };
in {
  nixosConfigurations = {
    # ... existing configs
    my-new-pc = mkSystem {
      hostConfig = hosts.my-new-pc;
      userSettings = users.henhal;
    };
  };
}
```

### Step 4: Build and Switch

```bash
# Build first to catch errors
nixos-rebuild build --flake .#my-new-pc

# If successful, switch
sudo nixos-rebuild switch --flake .#my-new-pc
```

---

## Modifying an Existing Host

### Change Desktop Session

Edit `hosts/<hostname>.nix`:

```nix
desktop = {
  session = "sway";  # Changed from "hyprland"
  # bar, lock, idle will now use sway defaults
};
```

Rebuild:
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### Override Default Components

```nix
desktop = {
  session = "hyprland";
  bar = "waybar";      # Use waybar instead of default hyprpanel
  lock = "swaylock";   # Use swaylock instead of default hyprlock
};
```

### Add/Change Monitors

```nix
desktop = {
  session = "hyprland";

  monitors = [
    # Updated monitor config
    "DP-1,2560x1440@165,0x0,1"
    "DP-2,2560x1440@165,2560x0,1"
  ];

  workspaceRules = [
    "1, monitor:DP-1, default:true"
    "2, monitor:DP-1"
    "3, monitor:DP-2, default:true"
    "4, monitor:DP-2"
  ];
};
```

### Change Theme

Edit user settings in `flake.nix`:

```nix
stylixTheme = {
  scheme = "catppuccin-mocha";
  wallpaper = "new-wallpaper.png";  # Must exist in assets/wallpapers/
};
```

---

## Component Reference

### Sessions

#### Hyprland (`session = "hyprland"`)

Wayland compositor with animations and effects.

**Host options:**
- `monitors` - Monitor configuration list
- `workspaceRules` - Workspace-to-monitor assignments
- `extraConfig` - Raw Hyprland config

**NixOS enables:**
- `programs.hyprland`
- `xdg-desktop-portal-hyprland`
- `security.pam.services.hyprlock`

#### Sway (`session = "sway"`)

i3-compatible Wayland compositor.

**Host options:**
- `outputs` - Output configuration attrset
- `extraConfig` - Raw Sway config

**NixOS enables:**
- `programs.sway`
- `xdg-desktop-portal-wlr`
- `security.pam.services.swaylock`

#### GNOME (`session = "gnome"`)

Full GNOME desktop environment.

**NixOS enables:**
- `services.xserver.desktopManager.gnome`
- GDM display manager

### Bars

#### Hyprpanel (`bar = "hyprpanel"`)

Modern panel for Hyprland with widgets.

**Host options:**
```nix
desktop.hyprpanel = {
  bar.position = "top";
  # Additional hyprpanel config
};
```

#### Waybar (`bar = "waybar"`)

Highly customizable Wayland bar.

Uses Stylix colors automatically. No additional host config needed.

### Lock Screens

#### Hyprlock (`lock = "hyprlock"`)

Lock screen for Hyprland. Uses wallpaper from Stylix with blur effect.

#### Swaylock (`lock = "swaylock"`)

Lock screen for Sway/wlroots. Uses Stylix colors for indicators.

### Idle Daemons

#### Hypridle (`idle = "hypridle"`)

Idle daemon for Hyprland.

Default behavior:
- 5 minutes: Lock screen
- 10 minutes: Turn off displays

#### Swayidle (`idle = "swayidle"`)

Idle daemon for Sway.

Default behavior:
- 5 minutes: Lock screen
- 10 minutes: Turn off displays

### Display Managers

#### SDDM (`dm = "sddm"`)

Default for Hyprland/Sway. Uses Stylix wallpaper and colors.

Features:
- Wayland mode
- Auto-login (configurable)
- Themed with Stylix

#### GDM (`dm = "gdm"`)

Default for GNOME. Standard GDM configuration.

---

## Theming

All components use Stylix for consistent theming.

### How Theming Works

1. Theme defined in `userSettings.stylixTheme`
2. `lib/theme.nix` maps scheme name to base16 file
3. Both NixOS and HM Stylix modules use `lib/theme.nix`
4. Individual components read from `config.stylix.*` or `config.lib.stylix.colors`

### Components That Use Stylix

| Component | Colors | Fonts | Wallpaper |
|-----------|--------|-------|-----------|
| SDDM | Yes | Yes | Yes |
| Rofi | Yes | Yes | No |
| Waybar | Yes | Yes | No |
| Hyprpanel | Mapped* | No | No |
| Hyprlock | Yes | Yes | Yes |
| Swaylock | Yes | No | Yes |
| Mako | Yes | Yes | No |
| GTK apps | Yes | Yes | No |
| Qt apps | Yes | Yes | No |

*Hyprpanel uses a theme name mapping, not direct Stylix colors.

### Adding a New Wallpaper

1. Add image to `assets/wallpapers/`
2. Update user settings:

```nix
stylixTheme = {
  scheme = "gruvbox-dark-hard";
  wallpaper = "my-new-wallpaper.png";
};
```

### Adding a New Theme

1. Find the base16 scheme name (from `pkgs.base16-schemes`)
2. Add to `lib/theme.nix`:

```nix
schemes = {
  # ... existing schemes
  "my-new-theme" = "${pkgs.base16-schemes}/share/themes/my-new-theme.yaml";
};
```

3. If using Hyprpanel, add mapping in `home/modules/desktop/bars/hyprpanel.nix`:

```nix
themeMap = {
  # ... existing mappings
  "my-new-theme" = "hyprpanel_theme_name";
};
```

---

## Examples

### Desktop PC with Dual Monitors

```nix
# hosts/desktop.nix
{
  hostname = "desktop";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";

    monitors = [
      "DP-1,3440x1440@144,0x0,1"       # Ultrawide main
      "DP-2,2560x1440@144,3440x0,1"    # Secondary to the right
    ];

    workspaceRules = [
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-1"
      "3, monitor:DP-1"
      "4, monitor:DP-2, default:true"
      "5, monitor:DP-2"
      "6, monitor:DP-2"
    ];
  };

  hardware = {
    gpu = "nvidia";
    logitech = true;
  };
}
```

### Laptop with HiDPI Display

```nix
# hosts/laptop.nix
{
  hostname = "laptop";

  desktop = {
    session = "sway";
    bar = "waybar";

    outputs = {
      "eDP-1" = {
        resolution = "2880x1800@120Hz";
        scale = 1.5;
      };
    };

    extraConfig = ''
      input type:touchpad {
        tap enabled
        natural_scroll enabled
        dwt enabled
      }
    '';
  };

  hardware = {
    gpu = "amd";
  };
}
```

### Headless Server

```nix
# hosts/server.nix
{
  hostname = "server";

  desktop = {
    session = "none";
  };

  hardware = {};
}
```

### Hyprland with Waybar (Override Default)

```nix
# hosts/hyprland-waybar.nix
{
  hostname = "hyprland-waybar";

  desktop = {
    session = "hyprland";
    bar = "waybar";        # Override: waybar instead of hyprpanel
    lock = "hyprlock";     # Explicit, same as default
    idle = "hypridle";     # Explicit, same as default

    monitors = [
      ",preferred,auto,1"
    ];
  };

  hardware = {};
}
```

---

## Troubleshooting

### Build Fails

```bash
# Check syntax
nix flake check

# Build with verbose output
nixos-rebuild build --flake .#<hostname> --show-trace
```

### Desktop Doesn't Start

1. Check display manager status:
```bash
systemctl status display-manager
```

2. Check session logs:
```bash
journalctl --user -u hyprland  # or sway
```

3. Verify monitor config:
```bash
hyprctl monitors  # Hyprland
swaymsg -t get_outputs  # Sway
```

### Wrong Lock Screen

Ensure `lock` is set correctly or let it default:

```nix
desktop = {
  session = "hyprland";
  lock = null;  # Will use hyprlock (hyprland default)
};
```

### Theme Not Applying

1. Rebuild both NixOS and HM:
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

2. Restart the session (logout/login)

3. For GTK apps, try:
```bash
gsettings reset org.gnome.desktop.interface gtk-theme
```

### Monitor Not Detected

1. Check connected monitors:
```bash
hyprctl monitors all  # Hyprland
swaymsg -t get_outputs  # Sway
```

2. Use fallback config:
```nix
monitors = [
  ",preferred,auto,1"  # Auto-detect
];
```

### Rollback

If something breaks:

```bash
# From GRUB: select previous generation

# Or from command line:
sudo nixos-rebuild switch --rollback
```

---

## Migration from Old System

If migrating from the old `windowManager` variable system:

1. Create `hosts/<hostname>.nix` with your current settings
2. Move monitor configs from `home/modules/window-manager/hyprland.nix` to host file
3. Remove `windowManager` from flake.nix
4. Update system configuration to remove WM conditionals
5. Test build before switching

See `REFACTOR_PLAN.md` for detailed migration steps.
