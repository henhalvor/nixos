# Desktop Configuration Modularization Plan v2.0

> **Improvements from v1.0**: Fixed invalid Nix patterns, replaced shell aliases with real binaries, improved option naming, removed session-based gating, added validation/assertions, abstracted duplicate code.

## Executive Summary

This plan addresses hardcoded Wayland-specific services and tools in shared desktop modules that prevent seamless switching between desktop environments (Hyprland, Sway, GNOME, etc.).

**Goal**: Transform the current "Wayland-centric common module" into a truly universal desktop system where all session-specific tools are modular, configurable, and dispatcher-driven.

### Key Improvements from v1.0

1. **Fixed Critical Issues**:
   - ✅ Removed `desktop.session != "gnome"` gating that blocks explicit overrides
   - ✅ Fixed invalid Nix patterns (`? ${}` → `builtins.hasAttr`)
   - ✅ Replaced shell aliases with proper wrapper binaries
   - ✅ Fixed clipboard service regression (text+image watchers)

2. **Better Architecture**:
   - ✅ Clearer option taxonomy (semantic names)
   - ✅ Abstracted duplicate systemd service code
   - ✅ Safer gammastep implementation (systemd service)
   - ✅ Added validation and assertions

3. **Improved Naming**:
   - `clipboard` → Stays, but clearer semantics
   - `screenshot` → `screenshotTool`
   - `applets` → `trayApplets`
   - `redshift` → `nightLight`
   - `notifications` → Separated from bar concern

### What's Wrong Now?

- `common.nix` hardcodes Wayland tools (wl-clipboard, grim, slurp) that conflict with GNOME
- Session modules hardcode clipboard managers and screenshot tools
- Bar modules hardcode applets and gammastep
- Switching from Hyprland → GNOME installs unnecessary/conflicting packages
- **Invalid Nix patterns** in dispatcher code
- **Shell aliases** don't work in systemd/compositor keybinds
- **Session-based gating** prevents explicit overrides

### The Solution

Add 5 new configurable desktop options following the existing pattern:
1. **clipboard**: clipman | cliphist | none (clipboard manager)
2. **screenshotTool**: grimblast | grim | none  
3. **trayApplets**: wayland | none (bluetooth/network applets)
4. **nightLight**: gammastep | redshift | none (color temperature)
5. **notifications**: mako | dunst | none (move to module directory)

### Impact

✅ Seamless DE switching - just change `desktop.session`  
✅ Zero conflicts between desktop environments  
✅ Consistent architecture - everything uses the dispatcher pattern  
✅ Easy to extend - add new tools by creating modules  
✅ Override flexibility - mix and match components  
✅ **Explicit overrides work** - no hidden session checks  
✅ **Real commands** - work everywhere (systemd, keybinds, all shells)  
✅ **Validation** - warns about incompatible combinations  

---

## Improved Architecture

### Option Naming & Semantics

```nix
# NEW semantic option names
desktop = {
  session = "hyprland";
  
  # Core components (unchanged)
  bar = null;                    # UI: hyprpanel | waybar | none
  lock = null;                   # Security: hyprlock | swaylock | loginctl
  idle = null;                   # Power: hypridle | swayidle | none
  
  # NEW modular components (improved names)
  clipboard = null;              # Data: clipman | cliphist | none
  screenshotTool = null;         # Media: grimblast | grim | none
  trayApplets = null;            # System: wayland | none
  nightLight = null;             # Display: gammastep | redshift | none
  notifications = null;          # Alerts: mako | dunst | none
};
```

### Session Defaults (Updated)

```nix
sessionDefaults = {
  hyprland = {
    bar = "hyprpanel";
    lock = "hyprlock";
    idle = "hypridle";
    clipboard = "clipman";
    screenshotTool = "grimblast";
    trayApplets = "wayland";
    nightLight = "gammastep";
    notifications = "mako";      # Changed from "hyprpanel"
  };
  
  sway = {
    bar = "waybar";
    lock = "swaylock";
    idle = "swayidle";
    clipboard = "clipman";
    screenshotTool = "grim";
    trayApplets = "wayland";
    nightLight = "gammastep";
    notifications = "mako";
  };
  
  gnome = {
    bar = "none";
    lock = "loginctl";
    idle = "none";
    clipboard = "none";           # GNOME built-in
    screenshotTool = "none";      # GNOME built-in
    trayApplets = "none";         # GNOME Shell built-in
    nightLight = "none";          # GNOME Night Light
    notifications = "none";       # GNOME built-in
  };
};
```

### Dispatcher Pattern (Fixed)

**BEFORE (Invalid)**:
```nix
# WRONG - Invalid Nix syntax
lib.optional (clipboardModules ? ${desktop.clipboard}) clipboardModules.${desktop.clipboard}
```

**AFTER (Correct)**:
```nix
# CORRECT - Valid Nix
lib.optional (builtins.hasAttr desktop.clipboard clipboardModules) clipboardModules.${desktop.clipboard}
```

**Complete Dispatcher** (`home/modules/desktop/default.nix`):
```nix
{ config, lib, pkgs, desktop, hostConfig, userSettings, ... }:
let
  # Lookup tables
  sessionModules = {
    hyprland = ./sessions/hyprland.nix;
    sway = ./sessions/sway.nix;
    gnome = ./sessions/gnome.nix;
  };

  barModules = {
    waybar = ./bars/waybar.nix;
    hyprpanel = ./bars/hyprpanel.nix;
  };

  lockModules = {
    hyprlock = ./lock/hyprlock.nix;
    swaylock = ./lock/swaylock.nix;
  };

  idleModules = {
    hypridle = ./idle/hypridle.nix;
    swayidle = ./idle/swayidle.nix;
  };

  notificationModules = {
    mako = ./notifications/mako.nix;
    dunst = ./notifications/dunst.nix;
    none = ./notifications/none.nix;
  };

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

  trayAppletModules = {
    wayland = ./applets/wayland.nix;
    none = ./applets/none.nix;
  };

  nightLightModules = {
    gammastep = ./nightlight/gammastep.nix;
    redshift = ./nightlight/redshift.nix;
    none = ./nightlight/none.nix;
  };

  enabled = desktop.session != "none";
  
  # Helper for safe module imports
  importModule = modules: key:
    lib.optional (builtins.hasAttr key modules) modules.${key};
in {
  imports = lib.optionals enabled ([
    ./common.nix
  ] 
  ++ importModule sessionModules desktop.session
  ++ importModule barModules desktop.bar
  ++ importModule lockModules desktop.lock
  ++ importModule idleModules desktop.idle
  ++ importModule notificationModules desktop.notifications
  ++ importModule clipboardModules desktop.clipboard
  ++ importModule screenshotModules desktop.screenshotTool
  ++ importModule trayAppletModules desktop.trayApplets
  ++ importModule nightLightModules desktop.nightLight
  );

  # Validation and warnings
  config = lib.mkIf enabled {
    # Warn about potentially incompatible combinations
    warnings = []
      ++ lib.optional (desktop.trayApplets != "none" && desktop.bar == "none")
        "desktop.trayApplets is enabled but desktop.bar is 'none' - applets may not display"
      ++ lib.optional (desktop.nightLight != "none" && desktop.session == "gnome")
        "desktop.nightLight is enabled with GNOME - may conflict with Night Light (use desktop.nightLight = 'none')";
    
    # Hard assertions for broken configurations
    assertions = [
      {
        assertion = builtins.hasAttr desktop.session sessionModules || desktop.session == "none";
        message = "Unknown desktop.session: ${desktop.session}";
      }
      {
        assertion = desktop.bar == "none" || builtins.hasAttr desktop.bar barModules;
        message = "Unknown desktop.bar: ${desktop.bar}";
      }
    ];
  };
}
```

### Shared Helper Library (`home/modules/desktop/lib.nix`)

```nix
{ lib, pkgs, ... }:
{
  # Helper to create wl-paste watcher services with consistent patterns
  mkWlPasteWatchService = {
    name,
    description,
    command,
    types ? [ "text" "image" ],  # Support both by default
    wantedBy ? [ "graphical-session.target" ],
  }: {
    Unit = {
      Description = description;
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = let
      # Create ExecStart commands for each type
      watchCommands = map (type: 
        "${pkgs.wl-clipboard}/bin/wl-paste --type ${type} --watch ${command}"
      ) types;
    in {
      # If multiple types, use a wrapper script
      ExecStart = if (builtins.length watchCommands) == 1
        then builtins.head watchCommands
        else pkgs.writeShellScript "${name}-watch" ''
          ${lib.concatMapStringsSep " & \n" (cmd: cmd) watchCommands}
          wait
        '';
      Restart = "on-failure";
    };

    Install = { WantedBy = wantedBy; };
  };

  # Helper to create toggle scripts for night light tools
  mkNightLightToggle = {
    name,           # "gammastep" or "redshift"
    package,        # pkgs.gammastep or pkgs.redshift
    temperature ? 3400,
    onMessage ? "${name} ON (${toString temperature}K)",
    offMessage ? "${name} Stopped",
  }: pkgs.writeShellScriptBin "nightlight-toggle" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Use systemd to manage the service
    if systemctl --user is-active ${name} >/dev/null 2>&1; then
      systemctl --user stop ${name}
      ${pkgs.libnotify}/bin/notify-send --expire-time=2000 "${offMessage}"
    else
      systemctl --user start ${name}
      ${pkgs.libnotify}/bin/notify-send --expire-time=1500 "${onMessage}"
    fi
  '';
}
```

---

## Module Implementations (Improved)

### 1. Clipboard Module (`clipboard/clipman.nix`)

```nix
{ config, lib, pkgs, desktop, ... }:
let
  desktopLib = import ../lib.nix { inherit lib pkgs; };
in {
  home.packages = with pkgs; [
    wl-clipboard
    clipman
    # Real command wrappers (NOT aliases)
    (pkgs.writeShellScriptBin "clipboard-history" ''
      ${pkgs.clipman}/bin/clipman pick -t rofi
    '')
    (pkgs.writeShellScriptBin "clipboard-clear" ''
      ${pkgs.clipman}/bin/clipman clear --all
    '')
  ];

  # Systemd service using shared helper (supports text + image)
  systemd.user.services.clipman = desktopLib.mkWlPasteWatchService {
    name = "clipman";
    description = "Clipman clipboard manager";
    command = "${pkgs.clipman}/bin/clipman store";
    types = [ "text" "image" ];  # Explicit: watch both types
  };
}
```

### 2. Screenshot Module (`screenshot/grimblast.nix`)

```nix
{ config, lib, pkgs, ... }:
let
  # Standardized screenshot command interface
  screenshotScript = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [ grimblast swappy coreutils ];
    text = ''
      case "''${1:-}" in
        --copy)
          grimblast copy area
          ;;
        --save)
          mkdir -p ~/Pictures/Screenshots
          grimblast save area ~/Pictures/Screenshots/"$(date +%Y-%m-%d_%H-%M-%S)".png
          ;;
        --swappy)
          grimblast save area - | swappy -f -
          ;;
        *)
          echo "Usage: screenshot [--copy|--save|--swappy]"
          exit 1
          ;;
      esac
    '';
  };
in {
  home.packages = [
    pkgs.grimblast
    pkgs.swappy
    screenshotScript
  ];
}
```

### 3. Night Light Module (`nightlight/gammastep.nix`)

```nix
{ config, lib, pkgs, ... }:
let
  desktopLib = import ../lib.nix { inherit lib pkgs; };
  temperature = 3400;
in {
  # Systemd service for gammastep (safer than manual toggle)
  systemd.user.services.gammastep = {
    Unit = {
      Description = "Gammastep color temperature adjuster";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${lib.getExe pkgs.gammastep} -O ${toString temperature}";
      Restart = "on-failure";
    };

    Install = {
      # Not started by default - user toggles it
      # WantedBy = [ "graphical-session.target" ];
    };
  };

  # Toggle command using systemd
  home.packages = [
    pkgs.gammastep
    (desktopLib.mkNightLightToggle {
      name = "gammastep";
      package = pkgs.gammastep;
      inherit temperature;
      onMessage = "Night Light ON (${toString temperature}K)";
      offMessage = "Night Light OFF";
    })
  ];
}
```

### 4. Tray Applets Module (`applets/wayland.nix`)

```nix
{ config, lib, pkgs, desktop, ... }:
{
  # System tray applets for Wayland compositors with external bars
  # Only enable if bar supports tray (optional validation)
  
  services.blueman-applet.enable = true;
  services.network-manager-applet.enable = true;

  home.packages = with pkgs; [
    blueman
    networkmanagerapplet
  ];
}
```

### 5. Notifications Module (`notifications/mako.nix`)

```nix
{ config, lib, pkgs, ... }:
{
  # Mako notification daemon - Stylix handles theming
  services.mako = {
    enable = true;
    # Use new settings format
    settings = {
      default-timeout = 5000;
      anchor = "top-right";
      max-visible = 5;
    };
  };
}
```

---

## Updated Implementation Phases

### Phase 1: Clipboard Modularization

**Changes from v1.0**:
- ✅ Use `pkgs.writeShellScriptBin` instead of shell aliases
- ✅ Use shared helper for systemd service
- ✅ Fix text+image watcher regression
- ✅ Remove session-based gating
- ✅ Fix dispatcher to use `builtins.hasAttr`

**Steps**:

1. **Create shared library**:
   ```bash
   touch home/modules/desktop/lib.nix
   # Copy mkWlPasteWatchService helper from above
   ```

2. **Create clipboard modules**:
   ```bash
   mkdir -p home/modules/desktop/clipboard
   # Create clipman.nix, cliphist.nix, none.nix using improved examples
   ```

3. **Update `lib/desktop.nix`**:
   ```nix
   sessionDefaults = {
     hyprland = {
       # ... existing options
       clipboard = "clipman";  # ADD THIS
     };
     # ... other sessions
   };

   # In resolveDesktop function:
   clipboard = desktop.clipboard or defaults.clipboard;
   ```

4. **Update dispatcher** (home/modules/desktop/default.nix):
   - Add clipboardModules lookup table
   - Use `builtins.hasAttr` pattern (see complete dispatcher above)
   - Add validation/warnings

5. **Remove from common.nix**: wl-clipboard, cliphist

6. **Remove from sessions**: clipman packages, exec-once commands

**Testing**:
```bash
# Test that commands exist and work
which clipboard-history clipboard-clear
clipboard-history

# Test systemd service
systemctl --user status clipman
journalctl --user -u clipman -f
```

### Phase 2: Screenshot Modularization

**Changes from v1.0**:
- ✅ Use `pkgs.writeShellApplication` for better error handling
- ✅ Explicit runtimeInputs
- ✅ Consistent command interface

**Implementation**: Follow same pattern as Phase 1, using improved screenshot modules.

### Phase 3: Tray Applets Modularization

**Changes from v1.0**:
- ✅ Renamed `applets` → `trayApplets` (clearer)
- ✅ Added warning for trayApplets without bar
- ✅ No session-based gating

### Phase 4: Night Light Modularization

**Changes from v1.0**:
- ✅ Renamed `redshift` → `nightLight` (semantic)
- ✅ Use systemd service instead of manual process management
- ✅ Shared toggle helper
- ✅ Much simpler and safer

### Phase 5: Notifications Module Directory

**Changes from v1.0**:
- ✅ Separated from bar concern
- ✅ GNOME uses none, Hyprland uses mako (not hyprpanel)
- ✅ Clearer separation of concerns

---

## Validation & Assertions

### Built-in Validation

```nix
# In home/modules/desktop/default.nix
config = lib.mkIf enabled {
  warnings = []
    # Warn about tray applets without bar
    ++ lib.optional (desktop.trayApplets != "none" && desktop.bar == "none")
      "desktop.trayApplets is '${desktop.trayApplets}' but desktop.bar is 'none' - applets may not display"
    
    # Warn about potential GNOME conflicts
    ++ lib.optional (desktop.nightLight != "none" && desktop.session == "gnome")
      "desktop.nightLight is '${desktop.nightLight}' with GNOME - may conflict with Night Light"
    
    # Warn about Wayland tools on X11 sessions (if we add X11 support)
    # ++ lib.optional (desktop.clipboard == "clipman" && desktop.backend == "x11")
    #   "desktop.clipboard 'clipman' requires Wayland but session uses X11";
  
  assertions = [
    {
      assertion = builtins.hasAttr desktop.session sessionModules || desktop.session == "none";
      message = "Unknown desktop.session: '${desktop.session}'. Valid options: ${lib.concatStringsSep ", " (builtins.attrNames sessionModules)}";
    }
    {
      assertion = desktop.bar == "none" || builtins.hasAttr desktop.bar barModules;
      message = "Unknown desktop.bar: '${desktop.bar}'. Valid options: none, ${lib.concatStringsSep ", " (builtins.attrNames barModules)}";
    }
    {
      assertion = builtins.hasAttr desktop.clipboard clipboardModules;
      message = "Unknown desktop.clipboard: '${desktop.clipboard}'. Valid options: ${lib.concatStringsSep ", " (builtins.attrNames clipboardModules)}";
    }
    # Add similar assertions for other options
  ];
};
```

### User-Friendly Error Messages

**Before**:
```
error: attribute 'clipman' missing
```

**After**:
```
error: Failed assertion: Unknown desktop.clipboard: 'clipman2'. 
Valid options: clipman, cliphist, none
```

---

## Alternative: mkDefault Pattern (Even Simpler)

Instead of custom `resolveDesktop` function, use NixOS module system's `lib.mkDefault`:

```nix
# In sessions/hyprland.nix
{ config, lib, ... }:
{
  # Set defaults directly in the session module
  desktop.clipboard = lib.mkDefault "clipman";
  desktop.screenshotTool = lib.mkDefault "grimblast";
  desktop.trayApplets = lib.mkDefault "wayland";
  desktop.nightLight = lib.mkDefault "gammastep";
  desktop.notifications = lib.mkDefault "mako";
  
  # ... rest of hyprland config
}
```

**Benefits**:
- ✅ No custom resolver function needed
- ✅ Defaults are discoverable in module system
- ✅ `mkDefault` is lower priority than user config (explicit overrides work)
- ✅ Standard NixOS pattern

**Tradeoff**: Session modules need to declare defaults (slightly less centralized than `lib/desktop.nix`).

---

## Success Criteria (Updated)

- [ ] All Wayland-specific packages removed from `common.nix`
- [ ] All services conditionally enabled via desktop options
- [ ] Clean switch between Hyprland, Sway, and GNOME with zero conflicts
- [ ] Session modules contain ONLY compositor-specific config
- [ ] Bar modules contain ONLY bar-specific config
- [ ] Every component follows the dispatcher pattern
- [ ] **All commands are real binaries** (not shell aliases)
- [ ] **No session-based gating** (modules work with explicit overrides)
- [ ] **Valid Nix syntax** throughout (no `? ${}` patterns)
- [ ] **Validation warnings** for incompatible combinations
- [ ] **Shared helpers** eliminate code duplication
- [ ] **Text + image clipboard** support maintained
- [ ] **Systemd services** for background processes (safer than manual toggles)
- [ ] Documentation updated for all new options
- [ ] All tests pass for each session type
- [ ] No duplicate processes when switching sessions
- [ ] No manual cleanup required when switching sessions

---

## Quick Reference (Updated)

### All Desktop Options

```nix
desktop = {
  # Core
  session = "hyprland";           # hyprland | sway | gnome | none
  
  # UI Components
  bar = null;                     # hyprpanel | waybar | none
  lock = null;                    # hyprlock | swaylock | loginctl | none
  idle = null;                    # hypridle | swayidle | none
  
  # System Tools (NEW - improved names)
  clipboard = null;               # clipman | cliphist | none
  screenshotTool = null;          # grimblast | grim | none
  trayApplets = null;             # wayland | none
  nightLight = null;              # gammastep | redshift | none
  notifications = null;           # mako | dunst | none
};
```

### Session Defaults Table

| Session | clipboard | screenshotTool | trayApplets | nightLight | notifications |
|---------|-----------|----------------|-------------|------------|---------------|
| **hyprland** | clipman | grimblast | wayland | gammastep | mako |
| **sway** | clipman | grim | wayland | gammastep | mako |
| **gnome** | none | none | none | none | none |

### Provided Commands (Standardized Interface)

```bash
# Clipboard (real binaries, not aliases)
clipboard-history       # Open clipboard history in rofi
clipboard-clear         # Clear clipboard history

# Screenshots
screenshot --copy       # Copy area to clipboard
screenshot --save       # Save area to ~/Pictures/Screenshots/
screenshot --swappy     # Open area in swappy editor

# Night Light
nightlight-toggle       # Toggle night light on/off (uses systemd)
```

---

*Last Updated: 2024*
*Architecture Version: 2.0*
*Status: Ready for Implementation*
