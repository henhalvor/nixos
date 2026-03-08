# Desktop Configuration System

Complete modular desktop configuration for NixOS + Home Manager with per-host customization, smart defaults, and full theming integration.

---

## Quick Start

### 5-Minute Setup

**Important:** A complete system configuration is defined in **3 different places**:
1. **`hosts/my-pc.nix`** - Host-specific settings (hostname, desktop session, hardware)
2. **`systems/my-pc/**`** - NixOS system configuration (configuration.nix, hardware-configuration.nix)
3. **`users/my-user/home.nix`** - User-specific Home Manager configuration

---

**1. Create a host configuration:**

```nix
# hosts/my-pc.nix
{
  hostname = "my-pc";
  
  desktop = {
    session = "hyprland";  # hyprland | sway | gnome
  };
  
  hardware = {};
}
```

**2. Create system configuration directory:**

```bash
# Create the systems directory for your host
mkdir -p systems/my-pc

# Generate hardware configuration
nixos-generate-config --show-hardware-config > systems/my-pc/hardware-configuration.nix

# Create basic configuration.nix (or copy from existing host)
# systems/my-pc/configuration.nix
```

**3. Configure your user:**

```nix
# users/my-user/home.nix
{ config, pkgs, ... }: {
  home.username = "my-user";
  home.homeDirectory = "/home/my-user";
  
  # Additional user-specific configuration
  # Terminal, browser, editor preferences, etc.
}
```

**4. Add to flake.nix:**

```nix
nixosConfigurations = {
  my-pc = mkSystem {
    hostConfig = hosts.my-pc;
    userSettings = users.my-user;
  };
};
```

**5. Build and switch:**

```bash
sudo nixos-rebuild switch --flake .#my-pc
```

**That's it!** Your system will use intelligent defaults for everything:
- ✅ Bar, lock screen, idle daemon auto-selected for your session
- ✅ Clipboard, screenshots, notifications configured automatically  
- ✅ Unified commands work regardless of backend tool
- ✅ Full theme integration via Stylix

### Override Specific Components

```nix
desktop = {
  session = "hyprland";
  bar = "waybar";              # Override default (hyprpanel)
  clipboard = "cliphist";      # Override default (clipman)
  screenshotTool = "grim";     # Override default (grimblast)
  notifications = "mako";      # Override default (none - hyprpanel has built-in)
};
```

### Available Options

```nix
desktop = {
  # Core
  session = "hyprland";           # hyprland | sway | gnome | none
  bar = null;                     # hyprpanel | waybar | none | null
  lock = null;                    # hyprlock | swaylock | loginctl | none | null
  idle = null;                    # hypridle | swayidle | none | null
  
  # Desktop Tools (NEW - fully modular)
  clipboard = null;               # clipman | cliphist | none | null
  screenshotTool = null;          # grimblast | grim | none | null
  notifications = null;           # mako | dunst | none | null
  trayApplets = null;             # wayland | none | null
  nightLight = null;              # gammastep | redshift | none | null
};
```

**Note**: `null` uses smart defaults based on your session type.

**Important**: Setting `idle` to anything other than `"none"` requires a valid lock screen (`lock != "none"`).
The system will fail to build if you set `idle = "hypridle"` but `lock = "none"`.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Design Philosophy](#design-philosophy)
3. [Implementation Details](#implementation-details)
4. [Directory Structure](#directory-structure)
5. [Session Defaults](#session-defaults)
6. [Module System](#module-system)
7. [Unified Commands](#unified-commands)
8. [Configuration Reference](#configuration-reference)
9. [Adding Components](#adding-components)
10. [Theming System](#theming-system)
11. [Examples](#examples)
12. [Troubleshooting](#troubleshooting)

---

## Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Pure Data Layer                          │
│                  hosts/<hostname>.nix                       │
│              (No imports, no logic, just data)              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                  Resolution Layer                           │
│               lib/mk-nixos-system.nix                       │
│   • Imports host config & user settings                    │
│   • Resolves null → session defaults (lib/desktop.nix)     │
│   • Creates specialArgs (desktop, hostConfig, userSettings) │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
┌──────────────────┐      ┌──────────────────────┐
│  NixOS Modules   │      │ Home Manager Modules │
│                  │      │                      │
│ • Display Mgr    │      │ • Sessions           │
│ • Sessions       │      │ • Bars               │
│ • Common         │      │ • Lock screens       │
│                  │      │ • Idle daemons       │
│                  │      │ • Clipboard          │
│                  │      │ • Screenshots        │
│                  │      │ • Notifications      │
│                  │      │ • Applets            │
│                  │      │ • Night light        │
└──────────────────┘      └──────────────────────┘
        │                           │
        └─────────────┬─────────────┘
                      ▼
          ┌──────────────────────┐
          │   Stylix Theming     │
          │  (Colors, Fonts,     │
          │   Wallpapers)        │
          └──────────────────────┘
```

### Data Flow

1. **Host File** (`hosts/my-pc.nix`) - Pure data, declares what you want
2. **Flake** (`flake.nix`) - Imports host + user, creates nixosConfiguration
3. **System Builder** (`lib/mk-nixos-system.nix`) - Resolves defaults, creates specialArgs
4. **Desktop Resolver** (`lib/desktop.nix`) - Provides session-specific defaults
5. **Dispatcher** (`home/modules/desktop/default.nix`) - Routes to correct modules
6. **Component Modules** - Implement specific functionality
7. **Stylix** - Applies consistent theming

### Key Concepts

**specialArgs**: Data passed to all modules
- `desktop` - Resolved desktop configuration (nulls replaced with defaults)
- `hostConfig` - Raw host data from hosts/*.nix
- `userSettings` - User preferences (terminal, browser, theme)

**Dispatcher Pattern**: Central router that imports correct modules based on configuration
- Uses lookup tables, not if/else chains
- Validates options at build time
- Prevents conflicting configurations

**Modular Components**: Each desktop tool is self-contained
- Packages, services, and configuration in one place
- Provides unified command interface
- Easy to add/remove/replace

---

## Design Philosophy

### 1. Pure Data in `hosts/`

Host files contain **only data** - no imports, no `lib`, no `pkgs`, no logic.

**Why?** 
- Easy to read and modify
- Clear separation of concerns
- Can be generated or templated
- No accidental coupling

```nix
# ✅ Good - pure data
{
  hostname = "my-pc";
  desktop.session = "hyprland";
  hardware.gpu = "nvidia";
}

# ❌ Bad - has logic/imports
{ pkgs, lib, ... }: {
  imports = [ ./some-module.nix ];
  desktop.session = if hostConfig.laptop then "sway" else "hyprland";
}
```

### 2. Modules Consume Data

Modules read host data and apply logic.

```nix
# Module uses hostConfig to make decisions
{ hostConfig, ... }: {
  services.xserver.videoDrivers =
    lib.mkIf (hostConfig.hardware.gpu == "nvidia") [ "nvidia" ];
}
```

### 3. Lookup Tables Over Conditionals

Use attrsets to map options to modules, not scattered if/else.

```nix
# ✅ Good - lookup table
clipboardModules = {
  clipman = ./clipboard/clipman.nix;
  cliphist = ./clipboard/cliphist.nix;
  none = ./clipboard/none.nix;
};

imports = lib.optional 
  (builtins.hasAttr desktop.clipboard clipboardModules)
  clipboardModules.${desktop.clipboard};

# ❌ Bad - scattered conditionals
imports = 
  if desktop.clipboard == "clipman" then [ ./clipboard/clipman.nix ]
  else if desktop.clipboard == "cliphist" then [ ./clipboard/cliphist.nix ]
  else [];
```

### 4. Defaults with Overrides

Sensible defaults per session; override only what differs.

```nix
# hyprland → uses hyprpanel, hyprlock, hypridle by default
desktop.session = "hyprland";

# Override only what you want to change
desktop = {
  session = "hyprland";
  bar = "waybar";  # Override default hyprpanel
};
```

### 5. Single Source of Truth

Each setting defined exactly once.

- Session defaults: `lib/desktop.nix`
- Component implementations: `home/modules/desktop/<component>/`
- Validation: `home/modules/desktop/default.nix`
- Theming: `lib/theme.nix`

### 6. Build-Time Validation

Catch errors at build time, not runtime.

```nix
assertions = [
  {
    assertion = builtins.hasAttr desktop.clipboard clipboardModules;
    message = "Unknown clipboard: '${desktop.clipboard}'. Valid: clipman, cliphist, none";
  }
];
```

### 7. Unified Command Interface

Same commands work regardless of backend implementation.

- `clipboard-history` works with clipman OR cliphist
- `screenshot --copy` works with grimblast OR grim
- `nightlight-toggle` works with gammastep OR redshift

---

## Implementation Details

### How Defaults Work

**1. User sets session:**
```nix
# hosts/my-pc.nix
desktop.session = "hyprland";
```

**2. Resolver applies defaults:**
```nix
# lib/desktop.nix
sessionDefaults = {
  hyprland = {
    bar = "hyprpanel";
    lock = "hyprlock";
    idle = "hypridle";
    clipboard = "clipman";
    screenshotTool = "grimblast";
    notifications = "none";  # Hyprpanel has built-in
    trayApplets = "wayland";
    nightLight = "gammastep";
  };
};

resolveDesktop = desktop: /* merges user config with defaults */
```

**3. Modules receive resolved config:**
```nix
# Component modules see:
desktop = {
  session = "hyprland";
  bar = "hyprpanel";        # From default
  lock = "hyprlock";        # From default
  clipboard = "clipman";    # From default
  # ... etc
};
```

### How Modules are Loaded

**1. Dispatcher creates lookup tables:**
```nix
# home/modules/desktop/default.nix
clipboardModules = {
  clipman = ./clipboard/clipman.nix;
  cliphist = ./clipboard/cliphist.nix;
  none = ./clipboard/none.nix;
};
```

**2. Imports correct module:**
```nix
imports = lib.optional
  (builtins.hasAttr desktop.clipboard clipboardModules)
  clipboardModules.${desktop.clipboard};
```

**3. Validates configuration:**
```nix
assertions = [{
  assertion = builtins.hasAttr desktop.clipboard clipboardModules;
  message = "Unknown clipboard option";
}];
```

### How Unified Commands Work

**1. Module provides wrapper script:**
```nix
# clipboard/clipman.nix
home.packages = [
  (pkgs.writeShellScriptBin "clipboard-history" ''
    ${pkgs.clipman}/bin/clipman pick -t rofi
  '')
];

# clipboard/cliphist.nix  
home.packages = [
  (pkgs.writeShellScriptBin "clipboard-history" ''
    ${pkgs.cliphist}/bin/cliphist list | rofi -dmenu | cliphist decode | wl-copy
  '')
];
```

**2. Session config uses unified command:**
```nix
# sessions/hyprland.nix
bind = [
  "$mainMod, O, exec, clipboard-history"  # Same command for both backends
];
```

### How Conflicts are Prevented

**Problem**: Hyprpanel has built-in AGS notifications that conflict with mako.

**Solution**: Build-time assertion with helpful error.

```nix
assertions = [{
  assertion = !(desktop.bar == "hyprpanel" && desktop.notifications == "mako");
  message = ''
    Incompatible: hyprpanel + mako both provide notifications.
    
    Fix:
      1. Use hyprpanel's notifications: notifications = "none"
      2. Use different bar: bar = "waybar" + notifications = "mako"
  '';
}];
```

---

## Directory Structure

```
.dotfiles/
├── flake.nix                    # Entry point, defines nixosConfigurations
│
├── hosts/                       # Pure data files (NO imports, NO logic)
│   ├── workstation.nix          # Desktop PC
│   ├── lenovo-yoga-pro-7.nix    # Laptop
│   └── hp-server.nix            # Headless server
│
├── lib/                         # Shared functions
│   ├── desktop.nix              # Session defaults & resolver
│   ├── theme.nix                # Stylix theme configuration
│   └── mk-nixos-system.nix      # System builder
│
├── systems/                     # Per-host NixOS configurations
│   ├── workstation/
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── ...
│
├── nixos/modules/               # Shared NixOS modules
│   ├── desktop/
│   │   ├── default.nix          # NixOS dispatcher
│   │   ├── common.nix           # Shared system config
│   │   ├── sessions/            # hyprland.nix, sway.nix, gnome.nix
│   │   └── display-managers/    # sddm.nix, gdm.nix
│   └── theme/stylix.nix         # NixOS Stylix config
│
├── home/modules/                # Shared Home Manager modules
│   ├── desktop/
│   │   ├── default.nix          # Home Manager dispatcher
│   │   ├── common.nix           # Common packages
│   │   ├── lib.nix              # Shared helpers (systemd services)
│   │   │
│   │   ├── sessions/            # Window managers/DEs
│   │   │   ├── hyprland.nix
│   │   │   ├── sway.nix
│   │   │   └── gnome.nix
│   │   │
│   │   ├── bars/                # Status bars
│   │   │   ├── waybar.nix
│   │   │   ├── hyprpanel.nix
│   │   │   └── none.nix
│   │   │
│   │   ├── lock/                # Lock screens
│   │   │   ├── hyprlock.nix
│   │   │   ├── swaylock.nix
│   │   │   └── none.nix
│   │   │
│   │   ├── idle/                # Idle daemons
│   │   │   ├── hypridle.nix
│   │   │   ├── swayidle.nix
│   │   │   └── none.nix
│   │   │
│   │   ├── clipboard/           # Clipboard managers (NEW)
│   │   │   ├── clipman.nix      # Clipman + systemd service
│   │   │   ├── cliphist.nix     # Cliphist + systemd service
│   │   │   └── none.nix
│   │   │
│   │   ├── screenshot/          # Screenshot tools (NEW)
│   │   │   ├── grimblast.nix    # Grimblast wrapper
│   │   │   ├── grim.nix         # Grim wrapper
│   │   │   └── none.nix
│   │   │
│   │   ├── notifications/       # Notification daemons (NEW)
│   │   │   ├── mako.nix
│   │   │   ├── dunst.nix
│   │   │   └── none.nix
│   │   │
│   │   ├── applets/             # System tray applets (NEW)
│   │   │   ├── wayland.nix      # Blueman + NetworkManager
│   │   │   └── none.nix
│   │   │
│   │   ├── nightlight/          # Night light (NEW)
│   │   │   ├── gammastep.nix
│   │   │   ├── redshift.nix
│   │   │   └── none.nix
│   │   │
│   │   └── rofi/                # Application launcher
│   │
│   └── themes/stylix/           # Home Manager Stylix config
│
├── users/                       # Per-user Home Manager configs
│   └── henhal/
│       └── home.nix
│
├── assets/
│   ├── wallpapers/              # Theme wallpapers
│   └── themes/                  # Custom theme files
│
└── docs/
    └── DESKTOP_CONFIGURATION.md # This file
```

---

## Session Defaults

When you set an option to `null`, it uses the session's default:

### Hyprland Session

```nix
desktop.session = "hyprland";  # Sets these defaults:
```

| Option | Default | Why? |
|--------|---------|------|
| `bar` | hyprpanel | Modern, feature-rich panel for Hyprland |
| `lock` | hyprlock | Native Hyprland lock screen |
| `idle` | hypridle | Native Hyprland idle daemon |
| `clipboard` | clipman | Lightweight, works well with Wayland |
| `screenshotTool` | grimblast | Optimized for Hyprland |
| `notifications` | **none** | Hyprpanel has built-in AGS notifications |
| `trayApplets` | wayland | Blueman + NetworkManager applets |
| `nightLight` | gammastep | Modern Wayland color temperature tool |

### Niri Session

```nix
desktop.session = "niri";  # Sets these defaults:
```

| Option | Default | Why? |
|--------|---------|------|
| `bar` | waybar | Native Waybar support, including `niri/workspaces` |
| `lock` | swaylock | Stable Wayland lock screen that works well with Niri |
| `idle` | swayidle | Reuses the existing idle stack with Niri monitor power actions |
| `clipboard` | clipman | Lightweight, works well with Wayland |
| `screenshotTool` | grim | Compositor-agnostic screenshot flow |
| `notifications` | mako | Lightweight Wayland notification daemon |
| `trayApplets` | wayland | Blueman + NetworkManager applets |
| `nightLight` | gammastep | Modern Wayland color temperature tool |

### Sway Session

```nix
desktop.session = "sway";  # Sets these defaults:
```

| Option | Default | Why? |
|--------|---------|------|
| `bar` | waybar | Highly customizable, i3/sway standard |
| `lock` | swaylock | Native Sway lock screen |
| `idle` | swayidle | Native Sway idle daemon |
| `clipboard` | clipman | Lightweight, works well with Wayland |
| `screenshotTool` | grim | Standard Wayland screenshot tool |
| `notifications` | mako | Lightweight Wayland notification daemon |
| `trayApplets` | wayland | Blueman + NetworkManager applets |
| `nightLight` | gammastep | Modern Wayland color temperature tool |

### GNOME Session

```nix
desktop.session = "gnome";  # Sets these defaults:
```

| Option | Default | Why? |
|--------|---------|------|
| All | **none** | GNOME has everything built-in |

### None (Headless)

```nix
desktop.session = "none";  # Sets these defaults:
```

| Option | Default | Why? |
|--------|---------|------|
| All | **none** | Server/headless system |

---

## Module System

### Module Structure

Each component type follows this pattern:

```
<component>/
├── <implementation-1>.nix    # Full implementation
├── <implementation-2>.nix    # Alternative implementation
└── none.nix                  # Empty placeholder
```

### Example: Clipboard Module

**`clipboard/clipman.nix`**
```nix
{ config, lib, pkgs, ... }:
let
  desktopLib = import ../lib.nix { inherit lib pkgs; };
in {
  # Packages
  home.packages = with pkgs; [
    wl-clipboard
    clipman
    # Unified commands
    (pkgs.writeShellScriptBin "clipboard-history" ''
      ${pkgs.clipman}/bin/clipman pick -t rofi
    '')
    (pkgs.writeShellScriptBin "clipboard-clear" ''
      ${pkgs.clipman}/bin/clipman clear --all
    '')
  ];

  # Systemd service (auto-start, auto-restart)
  systemd.user.services.clipman = desktopLib.mkWlPasteWatchService {
    name = "clipman";
    description = "Clipman clipboard manager";
    command = "${pkgs.clipman}/bin/clipman store";
    types = [ "text" "image" ];
  };
}
```

**What this provides:**
- ✅ Packages: clipman, wl-clipboard
- ✅ Commands: `clipboard-history`, `clipboard-clear`
- ✅ Service: Auto-starts and watches clipboard
- ✅ Integration: Works with both text and images

### Shared Library (`lib.nix`)

Provides reusable helpers to avoid duplication:

```nix
{ lib, pkgs, ... }:
{
  # Create wl-paste watcher systemd service
  mkWlPasteWatchService = { name, description, command, types ? ["text" "image"], ... }: {
    Unit = {
      Description = description;
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = /* generates wl-paste watch command */;
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
```

**Used by:** clipboard modules, screenshot modules (for clipboard integration)

### Dispatcher (`default.nix`)

Central router that loads correct modules:

```nix
{ config, lib, pkgs, desktop, ... }:
let
  # Lookup tables
  clipboardModules = {
    clipman = ./clipboard/clipman.nix;
    cliphist = ./clipboard/cliphist.nix;
    none = ./clipboard/none.nix;
  };
  
  screenshotModules = {
    grimblast = ./screenshot/grimblast.nix;
    grim = ./screenshot/grim.nix;
    none = ./screenshot/none.nix;
  };
  
  # ... more lookup tables
  
  # Safe import helper
  importModule = modules: key:
    lib.optional (key != null && builtins.hasAttr key modules) modules.${key};
in {
  # Load modules based on desktop config
  imports = lib.optionals (desktop.session != "none") ([
    ./common.nix
  ]
  ++ importModule sessionModules desktop.session
  ++ importModule clipboardModules desktop.clipboard
  ++ importModule screenshotModules desktop.screenshotTool
  # ... more imports
  );
  
  # Validate configuration
  config = lib.mkIf (desktop.session != "none") {
    assertions = [
      {
        assertion = builtins.hasAttr desktop.clipboard clipboardModules;
        message = "Unknown clipboard: '${desktop.clipboard}'";
      }
      # ... more validations
    ];
  };
}
```

---

## Unified Commands

### Clipboard Commands

**`clipboard-history`** - Open clipboard history picker

Works with:
- Clipman: `clipman pick -t rofi`
- Cliphist: `cliphist list | rofi | cliphist decode | wl-copy`

**`clipboard-clear`** - Clear clipboard history

Works with:
- Clipman: `clipman clear --all`
- Cliphist: `cliphist wipe`

### Screenshot Commands

**`screenshot --copy`** - Screenshot to clipboard
**`screenshot --save`** - Screenshot to ~/Pictures/Screenshots/
**`screenshot --swappy`** - Screenshot with editor

Works with:
- Grimblast: Optimized Hyprland integration
- Grim: Standard Wayland screenshot tool

Both show notifications on completion.

### Night Light Commands

**`nightlight-toggle`** - Toggle night light on/off

Works with:
- Gammastep: Modern Wayland color temperature
- Redshift: Classic color temperature tool

Shows notification with current state.

---

## Configuration Reference

### Full Host Configuration Schema

```nix
# hosts/<hostname>.nix
{
  # Required
  hostname = "my-hostname";

  # Desktop configuration
  desktop = {
    # Required for desktop systems
    session = "hyprland";              # hyprland | niri | sway | gnome | none
    
    # Optional - null uses session defaults
    bar = null;                        # hyprpanel | waybar | none | null
    lock = null;                       # hyprlock | swaylock | loginctl | null
    idle = null;                       # hypridle | swayidle | none | null
    clipboard = null;                  # clipman | cliphist | none | null
    screenshotTool = null;             # grimblast | grim | none | null
    notifications = null;              # mako | dunst | none | null
    trayApplets = null;                # wayland | none | null
    nightLight = null;                 # gammastep | redshift | none | null

    # Hyprland-specific
    monitors = [                       # Monitor configurations
      "DP-1,3440x1440@144,0x0,1"
    ];
    workspaceRules = [                 # Workspace assignments
      "1, monitor:DP-1, default:true"
    ];

    # Sway-specific
    outputs = {                        # Output configurations
      "DP-1" = {
        resolution = "3440x1440@144Hz";
        position = "0,0";
      };
    };

    # Niri-specific
    # Repo-managed KDL config is symlinked to ~/.config/niri/
    # via Home Manager from:
    # home/modules/desktop/sessions/niri-config/

    # Extra configuration (any session)
    extraConfig = ''
      # Raw session config
    '';
    
    # Component overrides
    hyprpanel = {
      bar.position = "top";
    };
  };

  # Hardware configuration
  hardware = {
    gpu = "nvidia";                    # nvidia | amd | intel
    logitech = true;                   # Logitech wireless support
    bluetooth = true;                  # Bluetooth support
  };
}
```

### Monitor Configuration

**Hyprland format:**
```nix
monitors = [
  "name,resolution@rate,position,scale"
  
  # Examples:
  ",preferred,auto,1"                          # Auto-detect
  "DP-1,3440x1440@144,0x0,1"                  # Ultrawide main
  "DP-2,2560x1440@144,3440x0,1"               # Secondary right
  "eDP-1,2880x1800@120,0x0,1.5"               # Laptop HiDPI
  "HDMI-A-1,disable"                          # Disable output
];
```

**Sway format:**
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

**Niri format:**
```kdl
// home/modules/desktop/sessions/niri-config/hosts/<hostname>.kdl
output "DP-1" {
    mode "2560x1440"
    scale 1
    position x=1080 y=0
    focus-at-startup
}

output "HDMI-A-1" {
    mode "1920x1080"
    scale 1
    transform "90"
    position x=0 y=0
}

workspace "1" { open-on-output "HDMI-A-1" }
workspace "2" { open-on-output "DP-1" }
```

---

## Adding Components

### Adding a New Desktop Tool Category

**Example: Adding a compositor (picom, etc.)**

**1. Create module directory:**
```bash
mkdir home/modules/desktop/compositor
```

**2. Create implementation modules:**
```nix
# compositor/picom.nix
{ config, lib, pkgs, ... }:
{
  services.picom = {
    enable = true;
    # ... picom config
  };
  
  home.packages = [ pkgs.picom ];
}

# compositor/none.nix
{ ... }: { }
```

**3. Add to dispatcher:**
```nix
# home/modules/desktop/default.nix
let
  compositorModules = {
    picom = ./compositor/picom.nix;
    none = ./compositor/none.nix;
  };
in {
  imports = /* ... */ ++ importModule compositorModules desktop.compositor;
  
  config.assertions = [{
    assertion = builtins.hasAttr desktop.compositor compositorModules;
    message = "Unknown compositor: '${desktop.compositor}'";
  }];
}
```

**4. Add to session defaults:**
```nix
# lib/desktop.nix
sessionDefaults = {
  hyprland = {
    # ... existing defaults
    compositor = "none";  # Hyprland is a compositor
  };
  sway = {
    # ... existing defaults
    compositor = "none";  # Sway is a compositor
  };
  gnome = {
    # ... existing defaults
    compositor = "none";  # GNOME handles compositing
  };
};

resolveDesktop = desktop: /* ... */ // {
  compositor = if desktop.compositor or null != null 
    then desktop.compositor 
    else defaults.compositor;
};
```

**5. Use in host config:**
```nix
desktop = {
  session = "hyprland";
  compositor = "picom";  # Override default
};
```

### Adding an Alternative Implementation

**Example: Adding `copyq` as clipboard option**

**1. Create module:**
```nix
# clipboard/copyq.nix
{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    copyq
    (pkgs.writeShellScriptBin "clipboard-history" ''
      ${pkgs.copyq}/bin/copyq menu
    '')
    (pkgs.writeShellScriptBin "clipboard-clear" ''
      ${pkgs.copyq}/bin/copyq clear
    '')
  ];
  
  services.copyq.enable = true;
}
```

**2. Add to lookup table:**
```nix
# home/modules/desktop/default.nix
clipboardModules = {
  clipman = ./clipboard/clipman.nix;
  cliphist = ./clipboard/cliphist.nix;
  copyq = ./clipboard/copyq.nix;     # Added
  none = ./clipboard/none.nix;
};
```

**3. Optionally set as default:**
```nix
# lib/desktop.nix
sessionDefaults = {
  hyprland = {
    clipboard = "copyq";  # Changed default
  };
};
```

---

## Theming System

### How Theming Works

1. **Theme defined** in `userSettings.stylixTheme`
2. **Theme mapped** in `lib/theme.nix` to base16 scheme file
3. **Stylix modules** (NixOS + Home Manager) apply theme
4. **Components** read from `config.stylix.*` or `config.lib.stylix.colors`

### Theme Configuration

```nix
# In flake.nix users section
stylixTheme = {
  scheme = "gruvbox-dark-hard";    # Base16 scheme name
  wallpaper = "starry-sky.png";     # In assets/wallpapers/
};
```

### Available Themes

| Scheme | Type | Description |
|--------|------|-------------|
| `catppuccin-mocha` | Dark | Soothing pastel dark theme |
| `catppuccin-macchiato` | Dark | Warmer Catppuccin variant |
| `gruvbox-dark-hard` | Dark | High contrast retro groove |
| `gruvbox-dark-medium` | Dark | Balanced contrast |
| `nord` | Dark | Arctic, north-bluish theme |
| `dracula` | Dark | Dark theme with vibrant colors |
| `rose-pine-moon` | Dark | Elegant dark theme |
| `tokyo-night-dark` | Dark | Clean, modern dark theme |
| `one-dark` | Dark | Atom's One Dark |

### Component Theme Integration

| Component | Colors | Fonts | Wallpaper | Notes |
|-----------|--------|-------|-----------|-------|
| **SDDM** | ✅ | ✅ | ✅ | Full Stylix integration |
| **Hyprland** | ✅ | ✅ | ✅ | Border colors, gaps |
| **Niri** | ✅ | ✅ | ✅ | Focus ring, shadows, gaps |
| **Sway** | ✅ | ✅ | ✅ | Border colors, gaps |
| **Rofi** | ✅ | ✅ | ❌ | Application launcher |
| **Waybar** | ✅ | ✅ | ❌ | Module colors |
| **Hyprpanel** | Mapped | ❌ | ❌ | Uses theme name mapping |
| **Hyprlock** | ✅ | ✅ | ✅ | Wallpaper with blur |
| **Swaylock** | ✅ | ❌ | ✅ | Indicator colors |
| **Mako** | ✅ | ✅ | ❌ | Notification styling |
| **Dunst** | ✅ | ✅ | ❌ | Notification styling |
| **GTK apps** | ✅ | ✅ | ❌ | System-wide |
| **Qt apps** | ✅ | ✅ | ❌ | System-wide |

### Adding a Custom Theme

**1. Find base16 scheme:**
- Browse: https://github.com/chriskempson/base16-schemes-source
- Or create custom scheme (YAML format)

**2. Add to `lib/theme.nix`:**
```nix
schemes = {
  # ... existing
  "my-custom-theme" = ./assets/themes/my-theme.yaml;
};
```

**3. Use in config:**
```nix
stylixTheme = {
  scheme = "my-custom-theme";
  wallpaper = "matching-wallpaper.png";
};
```

**4. For Hyprpanel, add theme mapping:**
```nix
# home/modules/desktop/bars/hyprpanel.nix
themeMap = {
  # ... existing
  "my-custom-theme" = "catppuccin_mocha";  # Maps to Hyprpanel theme
};
```

---

## Examples

### Example 1: Desktop PC (Dual Monitors)

```nix
# hosts/gaming-pc.nix
{
  hostname = "gaming-pc";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";
    
    monitors = [
      "DP-1,3440x1440@144,0x0,1"       # Ultrawide main
      "DP-2,2560x1440@144,3440x0,1"    # Secondary right
    ];

    workspaceRules = [
      "1, monitor:DP-1, default:true"  # Browser
      "2, monitor:DP-1"                # Terminal
      "3, monitor:DP-1"                # Code
      "4, monitor:DP-2, default:true"  # Discord
      "5, monitor:DP-2"                # Music
    ];
  };

  hardware = {
    gpu = "nvidia";
    logitech = true;
  };
}
```

### Example 2: Laptop (Power Efficient)

```nix
# hosts/laptop.nix
{
  hostname = "thinkpad";

  desktop = {
    session = "sway";           # More battery efficient
    bar = "waybar";
    nightLight = "redshift";    # Auto color temperature
    
    outputs = {
      "eDP-1" = {
        resolution = "2560x1440@60Hz";  # Lower refresh for battery
        scale = 1.25;
        position = "0,0";
      };
    };

    extraConfig = ''
      # Touchpad config
      input type:touchpad {
        tap enabled
        natural_scroll enabled
        dwt enabled
      }
    '';
  };

  hardware = {
    gpu = "intel";
    bluetooth = true;
  };
}
```

### Example 3: Hyprland with Waybar

```nix
# hosts/custom.nix
{
  hostname = "custom-desktop";

  desktop = {
    session = "hyprland";
    bar = "waybar";              # Override default hyprpanel
    clipboard = "cliphist";      # Override default clipman
    screenshotTool = "grim";     # Override default grimblast
    notifications = "mako";      # Override default none
    
    monitors = [
      ",preferred,auto,1"        # Auto-detect
    ];
  };

  hardware = {};
}
```

### Example 4: Minimal GNOME

```nix
# hosts/gnome-pc.nix
{
  hostname = "gnome-pc";

  desktop = {
    session = "gnome";
    # Everything else uses GNOME defaults (all "none")
  };

  hardware = {
    gpu = "amd";
  };
}
```

### Example 5: Headless Server

```nix
# hosts/server.nix
{
  hostname = "my-server";

  desktop = {
    session = "none";  # No desktop
  };

  hardware = {};
}
```

---

## Troubleshooting

### Build Errors

**Unknown option error:**
```
error: Unknown desktop.clipboard: 'clipman2'
Valid: clipman, cliphist, none
```

**Fix:** Check spelling, use a valid option from the error message.

**Conflicting configuration:**
```
error: Incompatible: hyprpanel + mako
Hyprpanel has built-in notifications.
```

**Fix:** Either use `notifications = "none"` or switch to `bar = "waybar"`.

**Idle/Lock configuration error:**
```
error: Incompatible configuration: desktop.idle = "hypridle" requires a lock screen.
```

**Fix:** Either disable idle (`idle = "none"`) or enable a lock screen (`lock = "hyprlock"`, `lock = "swaylock"`, or `lock = "loginctl"`).

### Runtime Issues

**Clipboard not working:**
```bash
# Check if service is running
systemctl --user status clipman  # or cliphist

# Restart service
systemctl --user restart clipman

# Check logs
journalctl --user -u clipman
```

**Screenshots not saving:**
```bash
# Verify directory exists
ls ~/Pictures/Screenshots/

# Test manually
screenshot --save

# Check notifications
systemctl --user status mako  # or dunst
```

**Night light not toggling:**
```bash
# Check if running
pgrep gammastep  # or redshift

# Test toggle
nightlight-toggle

# Check logs
journalctl --user | grep gammastep
```

**Monitor not detected:**
```bash
# Hyprland - check monitors
hyprctl monitors all

# Niri - check outputs
niri msg outputs

# Sway - check outputs
swaymsg -t get_outputs

# Use auto-detect fallback
monitors = [ ",preferred,auto,1" ];
```

### Validation

**Test configuration before switching:**
```bash
# Build without switching
nixos-rebuild build --flake .#<hostname>

# Check for errors
nix flake check

# Build with detailed errors
nixos-rebuild build --flake .#<hostname> --show-trace
```

**Rollback if needed:**
```bash
# From GRUB: select previous generation

# Or from command line:
sudo nixos-rebuild switch --rollback
```

### Common Fixes

**Clear Home Manager cache:**
```bash
rm -rf ~/.cache/home-manager
home-manager switch --flake .#<user>@<hostname>
```

**Rebuild everything:**
```bash
sudo nixos-rebuild switch --flake .#<hostname> --recreate-lock-file
```

**Check logs:**
```bash
# System logs
journalctl -xe

# User session logs
journalctl --user -xe

# Specific service
journalctl --user -u hyprland
```

---

## Migration Notes

### From Old Window Manager System

If migrating from previous `windowManager` variable system:

**1. Create host file** with current settings
**2. Move configurations:**
   - Monitor configs → host file
   - Component choices → host file
   - Remove `windowManager` variable

**3. Update structure:**
   - Old: `windowManager = "hyprland"`
   - New: `desktop.session = "hyprland"`

**4. Test build** before switching

### From Manual Configuration

**1. Identify components:**
   - What session? (Hyprland/Niri/Sway/GNOME)
   - What bar? (Waybar/Hyprpanel)
   - What clipboard manager?
   - What screenshot tool?

**2. Create host file** matching current setup

**3. Remove manual configs:**
   - Hardcoded packages
   - Explicit service enables
   - Duplicated configurations

**4. Use unified commands:**
   - Replace tool-specific keybinds
   - Use `clipboard-history`, `screenshot`, etc.

---

## Best Practices

### Configuration

✅ **DO:**
- Keep host files pure data
- Use null for defaults
- Override only what differs
- Use unified commands
- Test builds before switching

❌ **DON'T:**
- Add logic to host files
- Hardcode tool names in keybinds
- Duplicate session defaults
- Skip validation errors
- Force push to main without testing

### Organization

✅ **DO:**
- One host file per machine
- Group related configs
- Use meaningful names
- Document custom changes
- Keep backups

❌ **DON'T:**
- Mix host and user settings
- Scatter configs across files
- Use unclear abbreviations
- Skip commenting complex setups
- Delete working configs

### Maintenance

✅ **DO:**
- Update regularly
- Test on one host first
- Keep rollback generation
- Document breaking changes
- Review build logs

❌ **DON'T:**
- Update all hosts at once
- Skip reading changelogs
- Delete old generations immediately
- Ignore warnings
- Blindly copy configs

---

## Summary

This configuration system provides:

✅ **Modular Architecture** - Each component is self-contained and swappable
✅ **Smart Defaults** - Sensible choices per session type
✅ **Easy Overrides** - Change only what you need
✅ **Unified Interface** - Same commands regardless of backend
✅ **Build-Time Safety** - Catch errors before deployment
✅ **Full Theming** - Consistent look across all components
✅ **Zero Duplication** - Single source of truth for everything
✅ **Conflict Prevention** - Incompatible options caught automatically

**Start simple, customize as needed.** The system grows with your requirements.
