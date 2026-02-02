# Desktop Configuration Modularization Plan v2.1 (FINAL)

> **v2.1 Updates**: Switched to `lib.mkDefault` pattern (simpler!), fixed hyprpanel/mako conflict with clean validation.

## Executive Summary

This plan modularizes desktop configuration to support seamless switching between Hyprland, Sway, GNOME without conflicts.

**Key Simplification**: Uses standard NixOS `lib.mkDefault` pattern instead of custom resolver function.

### The Solution

Add 5 new configurable desktop options:
1. **clipboard**: clipman | cliphist | none
2. **screenshotTool**: grimblast | grim | none  
3. **trayApplets**: wayland | none
4. **nightLight**: gammastep | redshift | none
5. **notifications**: mako | dunst | none

**All use `lib.mkDefault`** - Session modules declare defaults, users can override.

---

## Architecture: lib.mkDefault Pattern

### How It Works

Instead of a custom `resolveDesktop` function, **session modules declare their own defaults** using `lib.mkDefault`:

```nix
# sessions/hyprland.nix
{ config, lib, pkgs, ... }:
{
  # Declare defaults with mkDefault (lower priority than user config)
  desktop.bar = lib.mkDefault "hyprpanel";
  desktop.lock = lib.mkDefault "hyprlock";
  desktop.idle = lib.mkDefault "hypridle";
  desktop.clipboard = lib.mkDefault "clipman";
  desktop.screenshotTool = lib.mkDefault "grimblast";
  desktop.trayApplets = lib.mkDefault "wayland";
  desktop.nightLight = lib.mkDefault "gammastep";
  desktop.notifications = lib.mkDefault "mako";
  
  # Rest of hyprland configuration...
}
```

### Benefits

✅ **Simpler**: No custom resolver function needed  
✅ **Standard**: Uses built-in NixOS module system  
✅ **Discoverable**: Defaults visible in module system  
✅ **Automatic**: `mkDefault` has lower priority than user config (overrides just work)  
✅ **Cleaner**: Each session owns its defaults  

### User Experience

```nix
# hosts/workstation.nix

# Minimal - uses all hyprland defaults
desktop.session = "hyprland";

# Override specific options - just set them!
desktop = {
  session = "hyprland";
  clipboard = "cliphist";      # Override works automatically
  notifications = "dunst";     # Override works automatically
};
```

---

## Handling Hyprpanel/Mako Conflict

### The Problem

- **Hyprpanel** has built-in AGS notification daemon
- **Mako** is a standalone notification daemon
- **Both cannot run together** - conflict on D-Bus notification interface

### The Solution: Simple Assertion

```nix
# In home/modules/desktop/default.nix dispatcher
assertions = [
  {
    assertion = !(desktop.bar == "hyprpanel" && desktop.notifications == "mako");
    message = ''
      Incompatible configuration: desktop.bar = "hyprpanel" and desktop.notifications = "mako".
      
      Hyprpanel includes its own notification daemon and conflicts with mako.
      
      Choose one:
        - Use hyprpanel's notifications: desktop.notifications = "none"
        - Use different bar: desktop.bar = "waybar"
    '';
  }
];
```

### Updated Hyprland Defaults

```nix
# sessions/hyprland.nix
{
  desktop.bar = lib.mkDefault "hyprpanel";
  desktop.notifications = lib.mkDefault "none";  # Hyprpanel handles notifications
  # ... other defaults
}
```

**Result**: Simple, clear error message if user explicitly sets incompatible combo.

---

## Complete Implementation

### 1. Remove Custom Resolver

**DELETE** `lib/desktop.nix` entirely! No longer needed.

### 2. Update Session Modules

Each session declares its own defaults:

#### `home/modules/desktop/sessions/hyprland.nix`

```nix
{ config, lib, pkgs, userSettings, desktop, hostConfig, ... }:
{
  # ===== DEFAULTS (using mkDefault) =====
  # These have lower priority than user config in hosts/*.nix
  
  desktop.bar = lib.mkDefault "hyprpanel";
  desktop.lock = lib.mkDefault "hyprlock";
  desktop.idle = lib.mkDefault "hypridle";
  desktop.clipboard = lib.mkDefault "clipman";
  desktop.screenshotTool = lib.mkDefault "grimblast";
  desktop.trayApplets = lib.mkDefault "wayland";
  desktop.nightLight = lib.mkDefault "gammastep";
  desktop.notifications = lib.mkDefault "none";  # Hyprpanel has built-in notifications
  
  # ===== HYPRLAND CONFIGURATION =====
  # Rest of hyprland config (window rules, keybinds, etc.)
  # NO package installations - handled by component modules
  
  wayland.windowManager.hyprland = {
    enable = true;
    # ... hyprland settings
  };
}
```

#### `home/modules/desktop/sessions/sway.nix`

```nix
{ config, lib, pkgs, userSettings, desktop, hostConfig, ... }:
{
  # ===== DEFAULTS =====
  desktop.bar = lib.mkDefault "waybar";
  desktop.lock = lib.mkDefault "swaylock";
  desktop.idle = lib.mkDefault "swayidle";
  desktop.clipboard = lib.mkDefault "clipman";
  desktop.screenshotTool = lib.mkDefault "grim";
  desktop.trayApplets = lib.mkDefault "wayland";
  desktop.nightLight = lib.mkDefault "gammastep";
  desktop.notifications = lib.mkDefault "mako";
  
  # ===== SWAY CONFIGURATION =====
  wayland.windowManager.sway = {
    enable = true;
    # ... sway settings
  };
}
```

#### `home/modules/desktop/sessions/gnome.nix`

```nix
{ config, lib, ... }:
{
  # ===== DEFAULTS =====
  # GNOME has everything built-in
  desktop.bar = lib.mkDefault "none";
  desktop.lock = lib.mkDefault "loginctl";
  desktop.idle = lib.mkDefault "none";
  desktop.clipboard = lib.mkDefault "none";
  desktop.screenshotTool = lib.mkDefault "none";
  desktop.trayApplets = lib.mkDefault "none";
  desktop.nightLight = lib.mkDefault "none";
  desktop.notifications = lib.mkDefault "none";
  
  # ===== GNOME CONFIGURATION =====
  # Minimal - GNOME handles most things
}
```

### 3. Dispatcher with Validation

```nix
# home/modules/desktop/default.nix
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
    none = ./bars/none.nix;
  };

  lockModules = {
    hyprlock = ./lock/hyprlock.nix;
    swaylock = ./lock/swaylock.nix;
    loginctl = ./lock/loginctl.nix;
    none = ./lock/none.nix;
  };

  idleModules = {
    hypridle = ./idle/hypridle.nix;
    swayidle = ./idle/swayidle.nix;
    none = ./idle/none.nix;
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

  # ===== VALIDATION =====
  config = lib.mkIf enabled {
    # Warnings for suboptimal but working configurations
    warnings = []
      ++ lib.optional (desktop.trayApplets != "none" && desktop.bar == "none")
        "desktop.trayApplets = '${desktop.trayApplets}' but desktop.bar = 'none' - applets won't display without a bar";
    
    # Hard assertions for broken configurations
    assertions = [
      # Session validation
      {
        assertion = builtins.hasAttr desktop.session sessionModules || desktop.session == "none";
        message = "Unknown desktop.session: '${desktop.session}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames sessionModules)}";
      }
      
      # Bar validation
      {
        assertion = builtins.hasAttr desktop.bar barModules;
        message = "Unknown desktop.bar: '${desktop.bar}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames barModules)}";
      }
      
      # Clipboard validation
      {
        assertion = builtins.hasAttr desktop.clipboard clipboardModules;
        message = "Unknown desktop.clipboard: '${desktop.clipboard}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames clipboardModules)}";
      }
      
      # Screenshot validation
      {
        assertion = builtins.hasAttr desktop.screenshotTool screenshotModules;
        message = "Unknown desktop.screenshotTool: '${desktop.screenshotTool}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames screenshotModules)}";
      }
      
      # Notifications validation
      {
        assertion = builtins.hasAttr desktop.notifications notificationModules;
        message = "Unknown desktop.notifications: '${desktop.notifications}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames notificationModules)}";
      }
      
      # Tray applets validation
      {
        assertion = builtins.hasAttr desktop.trayApplets trayAppletModules;
        message = "Unknown desktop.trayApplets: '${desktop.trayApplets}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames trayAppletModules)}";
      }
      
      # Night light validation
      {
        assertion = builtins.hasAttr desktop.nightLight nightLightModules;
        message = "Unknown desktop.nightLight: '${desktop.nightLight}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames nightLightModules)}";
      }
      
      # ===== CRITICAL: Hyprpanel/Mako Conflict =====
      {
        assertion = !(desktop.bar == "hyprpanel" && desktop.notifications == "mako");
        message = ''
          Incompatible configuration: desktop.bar = "hyprpanel" and desktop.notifications = "mako".
          
          Hyprpanel includes its own notification daemon (AGS notifications) and conflicts with mako.
          Both try to claim the D-Bus notification interface.
          
          Fix by choosing one:
            1. Use hyprpanel's built-in notifications:
               desktop.notifications = "none"
            
            2. Use a different bar with mako:
               desktop.bar = "waybar"
               desktop.notifications = "mako"
        '';
      }
      
      # Future: Add more conflict checks as needed
      # {
      #   assertion = !(desktop.bar == "hyprpanel" && desktop.notifications == "dunst");
      #   message = "Hyprpanel conflicts with dunst for the same reason as mako";
      # }
    ];
  };
}
```

---

## Module Implementations (Same as v2.0)

### Shared Library (`home/modules/desktop/lib.nix`)

```nix
{ lib, pkgs, ... }:
{
  # Helper to create wl-paste watcher services
  mkWlPasteWatchService = {
    name,
    description,
    command,
    types ? [ "text" "image" ],
    wantedBy ? [ "graphical-session.target" ],
  }: {
    Unit = {
      Description = description;
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = let
      watchCommands = map (type: 
        "${pkgs.wl-clipboard}/bin/wl-paste --type ${type} --watch ${command}"
      ) types;
    in {
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
}
```

### Clipboard Module (`clipboard/clipman.nix`)

```nix
{ config, lib, pkgs, ... }:
let
  desktopLib = import ../lib.nix { inherit lib pkgs; };
in {
  home.packages = with pkgs; [
    wl-clipboard
    clipman
    # Real command wrappers
    (pkgs.writeShellScriptBin "clipboard-history" ''
      ${pkgs.clipman}/bin/clipman pick -t rofi
    '')
    (pkgs.writeShellScriptBin "clipboard-clear" ''
      ${pkgs.clipman}/bin/clipman clear --all
    '')
  ];

  # Systemd service (text + image support)
  systemd.user.services.clipman = desktopLib.mkWlPasteWatchService {
    name = "clipman";
    description = "Clipman clipboard manager";
    command = "${pkgs.clipman}/bin/clipman store";
    types = [ "text" "image" ];
  };
}
```

### Screenshot Module (`screenshot/grimblast.nix`)

```nix
{ config, lib, pkgs, ... }:
let
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

### Night Light Module (`nightlight/gammastep.nix`)

```nix
{ config, lib, pkgs, ... }:
let
  temperature = 3400;
  
  toggleScript = pkgs.writeShellScriptBin "nightlight-toggle" ''
    #!/usr/bin/env bash
    set -euo pipefail
    
    if systemctl --user is-active gammastep >/dev/null 2>&1; then
      systemctl --user stop gammastep
      ${pkgs.libnotify}/bin/notify-send --expire-time=2000 "Night Light OFF"
    else
      systemctl --user start gammastep
      ${pkgs.libnotify}/bin/notify-send --expire-time=1500 "Night Light ON (${toString temperature}K)"
    fi
  '';
in {
  # Systemd service
  systemd.user.services.gammastep = {
    Unit = {
      Description = "Gammastep color temperature adjuster";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${lib.getExe pkgs.gammastep} -O ${toString temperature}";
      Restart = "on-failure";
    };
  };

  home.packages = [
    pkgs.gammastep
    toggleScript
  ];
}
```

### Notifications Module (`notifications/none.nix`)

```nix
{ ... }:
{
  # Empty module
  # Used when:
  # - GNOME (has built-in notifications)
  # - Hyprpanel (has AGS notifications built-in)
}
```

---

## Implementation Guide

### Phase 1: Clipboard

1. **Create shared library**:
   ```bash
   mkdir -p home/modules/desktop
   # Create lib.nix with mkWlPasteWatchService
   ```

2. **Create clipboard modules**:
   ```bash
   mkdir -p home/modules/desktop/clipboard
   # Create clipman.nix, cliphist.nix, none.nix
   ```

3. **Update dispatcher**:
   - Add clipboardModules lookup table
   - Add validation assertion
   - Add to imports

4. **Update session modules**:
   ```nix
   # In sessions/hyprland.nix - ADD THIS AT TOP:
   desktop.clipboard = lib.mkDefault "clipman";
   
   # DELETE from packages and exec-once:
   # - clipman
   # - wl-paste commands
   ```

5. **Remove from common.nix**:
   - wl-clipboard
   - cliphist

6. **Delete lib/desktop.nix**:
   ```bash
   rm lib/desktop.nix  # No longer needed!
   ```

7. **Update flake.nix** (if it imports lib/desktop.nix):
   ```nix
   # REMOVE any imports of lib/desktop.nix
   # Sessions now handle their own defaults with mkDefault
   ```

### Phase 2: Screenshot

Same pattern - create modules, update dispatcher, add mkDefault to sessions, remove from common.nix.

### Phase 3: Notifications

**Important**: Update hyprland defaults to use `notifications = "none"`:

```nix
# sessions/hyprland.nix
desktop.notifications = lib.mkDefault "none";  # Hyprpanel has built-in
```

Add assertion to catch hyprpanel+mako conflict.

### Phase 4: Tray Applets

Standard modularization.

### Phase 5: Night Light

Standard modularization with systemd service.

---

## Testing the Hyprpanel/Mako Conflict

### Test 1: Valid Hyprland Default
```nix
# hosts/workstation.nix
desktop.session = "hyprland";
# Uses defaults: bar = "hyprpanel", notifications = "none"
```
✅ Builds and runs successfully

### Test 2: Valid Override
```nix
desktop = {
  session = "hyprland";
  bar = "waybar";
  notifications = "mako";  # OK because not using hyprpanel
};
```
✅ Builds and runs successfully

### Test 3: Invalid Configuration
```nix
desktop = {
  session = "hyprland";
  bar = "hyprpanel";
  notifications = "mako";  # ERROR - conflicts with hyprpanel
};
```
❌ Build fails with clear error message:
```
error: Failed assertion: Incompatible configuration: desktop.bar = "hyprpanel" and desktop.notifications = "mako".

Hyprpanel includes its own notification daemon (AGS notifications) and conflicts with mako.
Both try to claim the D-Bus notification interface.

Fix by choosing one:
  1. Use hyprpanel's built-in notifications:
     desktop.notifications = "none"
  
  2. Use a different bar with mako:
     desktop.bar = "waybar"
     desktop.notifications = "mako"
```

---

## Session Defaults Summary

| Session | bar | clipboard | screenshotTool | trayApplets | nightLight | notifications |
|---------|-----|-----------|----------------|-------------|------------|---------------|
| **hyprland** | hyprpanel | clipman | grimblast | wayland | gammastep | **none** |
| **sway** | waybar | clipman | grim | wayland | gammastep | mako |
| **gnome** | none | none | none | none | none | none |

**Key**: Hyprland uses `notifications = "none"` because hyprpanel handles it.

---

## Benefits of v2.1

1. ✅ **Simpler**: No custom `lib/desktop.nix` resolver
2. ✅ **Standard**: Uses NixOS `lib.mkDefault` pattern
3. ✅ **Discoverable**: Defaults visible in session modules
4. ✅ **Automatic**: Overrides just work (no special logic)
5. ✅ **Conflict Prevention**: Clean assertion prevents hyprpanel/mako
6. ✅ **Clear Errors**: User knows exactly how to fix issues
7. ✅ **Less Code**: Removed entire resolver function
8. ✅ **More Maintainable**: Each session owns its defaults

---

## Quick Reference

### User Configuration Examples

**Minimal (uses all defaults)**:
```nix
desktop.session = "hyprland";
```

**Override clipboard**:
```nix
desktop = {
  session = "hyprland";
  clipboard = "cliphist";  # Just set it - mkDefault makes it work
};
```

**Use waybar with mako on Hyprland**:
```nix
desktop = {
  session = "hyprland";
  bar = "waybar";          # Override default hyprpanel
  notifications = "mako";   # Override default none (OK with waybar)
};
```

**Invalid (caught by assertion)**:
```nix
desktop = {
  session = "hyprland";
  # bar = "hyprpanel" (default)
  notifications = "mako";   # ERROR - conflicts with hyprpanel
};
```

---

## Migration from v2.0

1. **Delete `lib/desktop.nix`** - No longer needed
2. **Update session modules** - Add `lib.mkDefault` lines at top
3. **Update flake.nix** - Remove any `lib/desktop.nix` imports
4. **Update dispatcher** - Add hyprpanel/mako assertion
5. **Update hyprland defaults** - Set `notifications = "none"`

---

*This is the FINAL plan - simpler, cleaner, and handles the hyprpanel/mako conflict elegantly.*
