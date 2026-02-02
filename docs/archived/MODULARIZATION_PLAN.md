# Desktop Configuration Modularization Plan

## Executive Summary

This plan addresses hardcoded Wayland-specific services and tools in shared desktop modules that prevent seamless switching between desktop environments (Hyprland, Sway, GNOME, etc.).

**Goal**: Transform the current "Wayland-centric common module" into a truly universal desktop system where all session-specific tools are modular, configurable, and dispatcher-driven.

### What's Wrong Now?

- `common.nix` hardcodes Wayland tools (wl-clipboard, grim, slurp) that conflict with GNOME
- Session modules hardcode clipboard managers and screenshot tools
- Bar modules hardcode applets and gammastep
- Switching from Hyprland → GNOME installs unnecessary/conflicting packages

### The Solution

Add 5 new configurable desktop options following the existing pattern:
1. **clipboard**: clipman | cliphist | none
2. **screenshot**: grimblast | grim | none  
3. **applets**: wayland | none
4. **redshift**: gammastep | redshift | none
5. **notifications**: Move to module directory (already configurable)

### Impact

✅ Seamless DE switching - just change `desktop.session`  
✅ Zero conflicts between desktop environments  
✅ Consistent architecture - everything uses the dispatcher pattern  
✅ Easy to extend - add new tools by creating modules  
✅ Override flexibility - mix and match components  

### Implementation Effort

| Phase | Priority | Complexity | Files Changed | Testing |
|-------|----------|------------|---------------|---------|
| Phase 1: Clipboard | High | Low | 8 files | 30 min |
| Phase 2: Screenshot | High | Medium | 7 files | 30 min |
| Phase 3: Applets | Medium | Low | 6 files | 15 min |
| Phase 4: Redshift | Medium | Medium | 7 files | 20 min |
| Phase 5: Notifications | Low | Low | 6 files | 15 min |
| **Total** | - | - | **~30 files** | **~2 hours** |

### Timeline

- **Phase 1-2** (High priority): Implement first to fix GNOME conflicts
- **Phase 3-4** (Medium priority): Implement to complete Wayland modularization
- **Phase 5** (Low priority): Reorganization for consistency
- **Estimated total**: 4-6 hours of implementation + testing

---

## Detailed Architecture

### Current Dispatcher Flow

```
Host Config (hosts/workstation.nix)
  └─> desktop.session = "hyprland"
       └─> lib/desktop.nix (resolveDesktop)
            └─> Fills in defaults: bar, lock, idle, notifications
                 └─> home/modules/desktop/default.nix (dispatcher)
                      └─> Imports based on lookup tables:
                           ├─> sessions/${desktop.session}.nix
                           ├─> bars/${desktop.bar}.nix
                           ├─> lock/${desktop.lock}.nix
                           └─> idle/${desktop.idle}.nix
```

### Proposed Dispatcher Flow (After All Phases)

```
Host Config (hosts/workstation.nix)
  └─> desktop.session = "hyprland"
       └─> lib/desktop.nix (resolveDesktop)
            └─> Fills in ALL defaults:
                 ├─> bar = "hyprpanel"
                 ├─> lock = "hyprlock"
                 ├─> idle = "hypridle"
                 ├─> notifications = "hyprpanel"
                 ├─> clipboard = "clipman"         [NEW]
                 ├─> screenshot = "grimblast"      [NEW]
                 ├─> applets = "wayland"           [NEW]
                 └─> redshift = "gammastep"        [NEW]
                 
                 └─> home/modules/desktop/default.nix (dispatcher)
                      └─> Imports based on lookup tables:
                           ├─> common.nix (universal packages only)
                           ├─> sessions/${desktop.session}.nix
                           ├─> bars/${desktop.bar}.nix
                           ├─> lock/${desktop.lock}.nix
                           ├─> idle/${desktop.idle}.nix
                           ├─> notifications/${desktop.notifications}.nix  [NEW]
                           ├─> clipboard/${desktop.clipboard}.nix          [NEW]
                           ├─> screenshot/${desktop.screenshot}.nix        [NEW]
                           ├─> applets/${desktop.applets}.nix              [NEW]
                           └─> redshift/${desktop.redshift}.nix            [NEW]
```

### Module Responsibility Matrix

| Module Type | Responsibilities | What NOT to Include |
|-------------|------------------|---------------------|
| **common.nix** | Universal tools (all DEs) | Session-specific tools, services |
| **sessions/** | Compositor config, keybinds, window rules | Tool packages, clipboard, screenshots |
| **bars/** | Bar-specific config only | Applets, gammastep, notifications |
| **lock/** | Lock screen configuration | Session management |
| **idle/** | Idle management configuration | Lock implementation |
| **notifications/** | Notification daemon + config | Bar widgets |
| **clipboard/** | Clipboard manager + daemon | Session integration |
| **screenshot/** | Screenshot tools + wrapper script | Keybind definitions |
| **applets/** | System tray applets (BT, network) | Bar configuration |
| **redshift/** | Night light/color temp tools | Bar widgets |

### Dependency Graph

```
Session Module (hyprland.nix)
  └─> Defines keybinds that call:
       ├─> screenshot --copy     (provided by screenshot module)
       ├─> clipboard-history     (provided by clipboard module)
       └─> gamma-toggle          (provided by redshift module)

Bar Module (waybar.nix / hyprpanel.nix)
  └─> Shows widgets that call:
       ├─> gamma-toggle          (provided by redshift module)
       └─> clipboard-history     (provided by clipboard module)
       
Common Module (common.nix)
  └─> Provides only universal tools:
       ├─> libnotify  (used by all modules for notifications)
       ├─> playerctl  (media control)
       └─> pamixer    (audio control)
```

**Key Principle**: Modules provide CAPABILITIES (commands, daemons) that other modules can USE. No module should hardcode another module's tools.

---

## Current Problems

### 1. **Hardcoded Services in `common.nix`**

**File**: `home/modules/desktop/common.nix`

**Issues**:
- Wayland-specific packages unconditionally installed:
  - `wl-clipboard`, `cliphist` (clipboard - Wayland only)
  - `grim`, `slurp`, `swappy` (screenshots - Wayland only)
  - `libnotify`, `playerctl`, `brightnessctl`, `pamixer` (some are universal, some conflict)
  
- **Impact**: When switching to GNOME, these create redundancy and conflicts:
  - GNOME has built-in screenshot tool (`gnome-screenshot`)
  - GNOME has its own clipboard management
  - Installing Wayland tools when not needed wastes space

### 2. **Hardcoded Tools in Session Modules**

**Files**: 
- `home/modules/desktop/sessions/hyprland.nix`
- `home/modules/desktop/sessions/sway.nix`

**Issues**:
- Both hardcode `clipman` in packages AND startup commands (`exec-once`/`startup`)
- Both reference custom `screenshot` script with tool-specific implementations
- Clipboard manager choice is not configurable

### 3. **Bar Modules Hardcode Applets**

**File**: `home/modules/desktop/bars/waybar.nix`

**Issues**:
- Hardcodes `blueman-applet` and `network-manager-applet` services
- Hardcodes `gammastep` (red-shift alternative)
- **Impact**: GNOME has built-in bluetooth/network UI and Night Light feature
  - These applets conflict with GNOME Shell's built-in equivalents

### 4. **Inconsistent Service Enablement**

**Current State**:
- ✅ `notifications` - Properly abstracted with `desktop.notifications`
- ❌ `clipboard` - Hardcoded, not configurable
- ❌ `screenshot` - Hardcoded tool selection
- ❌ `applets` - Hardcoded in bar modules
- ❌ `gammastep` - Hardcoded in waybar

---

## Proposed Architecture

### Phase 1: Add New Desktop Options

Extend `lib/desktop.nix` to include new configurable options:

```nix
sessionDefaults = {
  hyprland = {
    bar = "hyprpanel";
    lock = "hyprlock";
    idle = "hypridle";
    notifications = "hyprpanel";
    clipboard = "clipman";          # NEW
    screenshot = "grimblast";       # NEW
    applets = "wayland";            # NEW (blueman + nm-applet)
    redshift = "gammastep";         # NEW
    dm = "sddm";
  };
  
  sway = {
    bar = "waybar";
    lock = "swaylock";
    idle = "swayidle";
    notifications = "mako";
    clipboard = "clipman";          # NEW
    screenshot = "grim";            # NEW
    applets = "wayland";            # NEW
    redshift = "gammastep";         # NEW
    dm = "sddm";
  };
  
  gnome = {
    bar = "none";
    lock = "loginctl";
    idle = "none";
    notifications = "none";         # GNOME built-in
    clipboard = "none";             # NEW - GNOME built-in
    screenshot = "none";            # NEW - GNOME built-in
    applets = "none";               # NEW - GNOME Shell built-in
    redshift = "none";              # NEW - GNOME Night Light
    dm = "gdm";
  };
};
```

### Phase 2: Create Modular Component Directories

#### 2.1 Clipboard Managers (`home/modules/desktop/clipboard/`)

**Structure**:
```
home/modules/desktop/clipboard/
├── clipman.nix      # Wayland clipboard (wl-clipboard + clipman)
├── cliphist.nix     # Alternative Wayland clipboard (wl-clipboard + cliphist)
└── none.nix         # Empty module for GNOME/other DEs
```

**Module Implementation Example** (`clipboard/clipman.nix`):
```nix
{ config, lib, pkgs, desktop, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    clipman
  ];

  # For Wayland compositors that need systemd integration
  systemd.user.services.clipman = lib.mkIf (desktop.session != "gnome") {
    Unit = {
      Description = "Clipman clipboard manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.clipman}/bin/clipman store";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Provide standardized clipboard command via shell alias
  home.shellAliases = {
    "clipboard-history" = "clipman pick -t rofi";
    "clipboard-clear" = "clipman clear --all";
  };
}
```

**Module Implementation Example** (`clipboard/cliphist.nix`):
```nix
{ config, lib, pkgs, desktop, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
  ];

  systemd.user.services.cliphist = lib.mkIf (desktop.session != "gnome") {
    Unit = {
      Description = "Cliphist clipboard manager";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.shellAliases = {
    "clipboard-history" = "cliphist list | rofi -dmenu | cliphist decode | wl-copy";
    "clipboard-clear" = "cliphist wipe";
  };
}
```

**Module Implementation Example** (`clipboard/none.nix`):
```nix
{ ... }:
{
  # Empty module for DEs with built-in clipboard management
  # GNOME, KDE, etc. have their own clipboard managers
}
```

**Dispatcher Integration** (`home/modules/desktop/default.nix`):
```nix
clipboardModules = {
  clipman = ./clipboard/clipman.nix;
  cliphist = ./clipboard/cliphist.nix;
  none = ./clipboard/none.nix;
};

imports = [
  # ... existing imports
  clipboardModules.${desktop.clipboard}
];
```

**Migration Steps**:
1. Remove `wl-clipboard`, `cliphist` from `common.nix` line 4-5
2. Remove `clipman` from `sessions/hyprland.nix` packages
3. Remove `clipman` from `sessions/sway.nix` line 48
4. Remove clipboard exec-once from `sessions/hyprland.nix` lines 120-121:
   ```nix
   # REMOVE THESE:
   "wl-paste --type text --watch clipman store &"
   "wl-paste --type image --watch clipman store &"
   ```
5. Remove clipboard startup from `sessions/sway.nix`
6. Update keybinds to use standardized aliases or keep rofi integration

#### 2.2 Screenshot Tools (`home/modules/desktop/screenshot/`)

**Structure**:
```
home/modules/desktop/screenshot/
├── grimblast.nix    # Hyprland (grimblast wrapper)
├── grim.nix         # Sway/Generic Wayland (grim + slurp + swappy)
└── none.nix         # GNOME/other DEs with built-in tools
```

**Module Implementation Example** (`screenshot/grimblast.nix`):
```nix
{ config, lib, pkgs, ... }:
let
  # Standardized screenshot script that works with grimblast
  screenshotScript = pkgs.writeShellScriptBin "screenshot" ''
    #!/usr/bin/env bash
    case "$1" in
      --copy)
        ${pkgs.grimblast}/bin/grimblast copy area
        ;;
      --save)
        mkdir -p ~/Pictures/Screenshots
        ${pkgs.grimblast}/bin/grimblast save area ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png
        ;;
      --swappy)
        ${pkgs.grimblast}/bin/grimblast save area - | ${pkgs.swappy}/bin/swappy -f -
        ;;
      *)
        echo "Usage: screenshot [--copy|--save|--swappy]"
        exit 1
        ;;
    esac
  '';
in {
  home.packages = with pkgs; [
    grimblast   # Hyprland-specific screenshot tool
    swappy      # Screenshot editor
    screenshotScript
  ];
}
```

**Module Implementation Example** (`screenshot/grim.nix`):
```nix
{ config, lib, pkgs, ... }:
let
  # Standardized screenshot script using grim + slurp
  screenshotScript = pkgs.writeShellScriptBin "screenshot" ''
    #!/usr/bin/env bash
    case "$1" in
      --copy)
        ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.wl-clipboard}/bin/wl-copy
        ;;
      --save)
        mkdir -p ~/Pictures/Screenshots
        ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png
        ;;
      --swappy)
        ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" - | ${pkgs.swappy}/bin/swappy -f -
        ;;
      *)
        echo "Usage: screenshot [--copy|--save|--swappy]"
        exit 1
        ;;
    esac
  '';
in {
  home.packages = with pkgs; [
    grim
    slurp
    swappy
    wl-clipboard  # Required for --copy option
    screenshotScript
  ];
}
```

**Module Implementation Example** (`screenshot/none.nix`):
```nix
{ ... }:
{
  # Empty module for DEs with built-in screenshot tools
  # GNOME: gnome-screenshot (Super+Shift+PrintScreen)
  # KDE: Spectacle
  # No additional packages needed
}
```

**Dispatcher Integration** (`home/modules/desktop/default.nix`):
```nix
screenshotModules = {
  grimblast = ./screenshot/grimblast.nix;
  grim = ./screenshot/grim.nix;
  none = ./screenshot/none.nix;
};

imports = [
  # ... existing imports
  screenshotModules.${desktop.screenshot}
];
```

**Migration Steps**:
1. Remove `grim`, `slurp`, `swappy` from `common.nix` lines 6-8
2. Remove `grimblast` from `bars/hyprpanel.nix` line 50
3. Screenshot keybinds in `sessions/hyprland.nix` already reference `screenshot` command - no changes needed!
4. Add similar keybinds to `sessions/sway.nix` if needed
5. The standardized `screenshot` command is now provided by the screenshot module

**Key Design Decision**: Each screenshot module provides a `screenshot` command with consistent interface:
- `screenshot --copy` - Copy to clipboard
- `screenshot --save` - Save to ~/Pictures/Screenshots/
- `screenshot --swappy` - Open in swappy editor

This means session keybinds can remain unchanged - they just call `screenshot --copy` etc.

#### 2.3 System Applets (`home/modules/desktop/applets/`)

**Structure**:
```
home/modules/desktop/applets/
├── wayland.nix      # blueman-applet + nm-applet for tray-based bars
└── none.nix         # For GNOME/DEs with built-in applets
```

**Module Implementation Example** (`applets/wayland.nix`):
```nix
{ config, lib, pkgs, ... }:
{
  # System tray applets for Wayland compositors with external bars
  # These provide GUI for bluetooth and network management
  
  services.blueman-applet.enable = true;
  services.network-manager-applet.enable = true;

  # Ensure required packages are available
  home.packages = with pkgs; [
    blueman      # Bluetooth manager
    networkmanagerapplet  # Network manager applet
  ];
}
```

**Module Implementation Example** (`applets/none.nix`):
```nix
{ ... }:
{
  # Empty module for DEs with integrated settings
  # GNOME Shell has built-in bluetooth/network controls
  # KDE Plasma has built-in system tray integration
  # No additional applets needed
}
```

**Dispatcher Integration** (`home/modules/desktop/default.nix`):
```nix
appletModules = {
  wayland = ./applets/wayland.nix;
  none = ./applets/none.nix;
};

imports = [
  # ... existing imports
  appletModules.${desktop.applets}
];
```

**Migration Steps**:
1. Remove from `bars/waybar.nix` lines 47-48:
   ```nix
   # REMOVE THESE:
   services.blueman-applet.enable = true;
   services.network-manager-applet.enable = true;
   ```
2. Applets are now session-agnostic, not bar-specific
3. Both waybar and hyprpanel can use the same applet configuration
4. GNOME automatically gets `applets = "none"` from session defaults

**Design Rationale**: 
- Applets should be tied to the SESSION, not the BAR
- Hyprpanel might use AGS widgets instead of tray applets (configurable)
- Waybar always shows system tray with applets
- Separating this from bar config makes it more flexible

#### 2.4 Redshift/Gammastep (`home/modules/desktop/redshift/`)

**Structure**:
```
home/modules/desktop/redshift/
├── gammastep.nix    # Wayland redshift alternative with toggle
├── redshift.nix     # X11 classic redshift with toggle
└── none.nix         # GNOME Night Light or other built-in
```

**Module Implementation Example** (`redshift/gammastep.nix`):
```nix
{ config, lib, pkgs, ... }:
let
  # Gammastep toggle script (same as current waybar implementation)
  gamma-toggle-script = pkgs.writeShellScriptBin "gamma-toggle" ''
    #!/usr/bin/env bash
    set -e

    STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}"
    gammastepStateDir="$STATE_HOME/gammastep"
    gammastepStateFile="$gammastepStateDir/default_temp.sh"
    mkdir -p "$gammastepStateDir"
    
    # Check if gammastep is running
    if ${pkgs.procps}/bin/pgrep -af gammastep | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|gamma-' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.gammastep}/bin/gammastep"; then
      # Kill gammastep
      pkill -f gammastep
      sleep 0.5
      if ${pkgs.procps}/bin/pgrep -af gammastep | ${pkgs.gnugrep}/bin/grep -v 'grep\|nvim\|pkill\|pgrep\|gamma-' | ${pkgs.gnugrep}/bin/grep -q "${pkgs.gammastep}/bin/gammastep"; then
         ${pkgs.libnotify}/bin/notify-send --expire-time=4000 "ERROR: RedGlow process still detected after pkill!"
      else
         ${pkgs.libnotify}/bin/notify-send --expire-time=2000 "RedGlow Stopped."
      fi
    else
      # Start gammastep
      if [ ! -f "$gammastepStateFile" ]; then echo "default_temp=3400" > "$gammastepStateFile"; fi
      ${pkgs.gammastep}/bin/gammastep -O 3400 &
      disown
      ${pkgs.libnotify}/bin/notify-send --expire-time=1500 "RedGlow ON (3400K)"
    fi
  '';
in {
  home.packages = with pkgs; [
    gammastep
    gamma-toggle-script
  ];

  # Optional: Enable gammastep service (auto-start based on time/location)
  # services.gammastep = {
  #   enable = true;
  #   provider = "manual";
  #   temperature.day = 6500;
  #   temperature.night = 3400;
  # };
}
```

**Module Implementation Example** (`redshift/redshift.nix`):
```nix
{ config, lib, pkgs, ... }:
let
  # Similar toggle script for X11 redshift
  redshift-toggle-script = pkgs.writeShellScriptBin "redshift-toggle" ''
    #!/usr/bin/env bash
    if pgrep -x redshift > /dev/null; then
      pkill redshift
      ${pkgs.libnotify}/bin/notify-send "Redshift OFF"
    else
      ${pkgs.redshift}/bin/redshift -O 3400 &
      ${pkgs.libnotify}/bin/notify-send "Redshift ON (3400K)"
    fi
  '';
in {
  home.packages = with pkgs; [
    redshift
    redshift-toggle-script
  ];
}
```

**Module Implementation Example** (`redshift/none.nix`):
```nix
{ ... }:
{
  # Empty module for DEs with built-in night light
  # GNOME: Settings > Displays > Night Light
  # KDE: Night Color
  # No additional packages needed
}
```

**Dispatcher Integration** (`home/modules/desktop/default.nix`):
```nix
redshiftModules = {
  gammastep = ./redshift/gammastep.nix;
  redshift = ./redshift/redshift.nix;
  none = ./redshift/none.nix;
};

imports = [
  # ... existing imports
  redshiftModules.${desktop.redshift}
];
```

**Migration Steps**:
1. Remove from `bars/waybar.nix` lines 6-35 (gamma-toggle-script let binding)
2. Remove from `bars/waybar.nix` line 42 (gammastep package)
3. Keep waybar module reference to toggle command:
   ```nix
   "custom/gammastep" = {
     format = "{icon}";
     format-icons = [ "󰔎" ];
     tooltip = false;
     on-click = "gamma-toggle";  # Command now provided by redshift module
   };
   ```
4. The toggle command is now universally available when redshift is enabled

**Bar Integration Note**: Bars can still show redshift controls - they just call the standardized toggle command provided by the redshift module. The bar module doesn't need to know which redshift implementation is used.

### Phase 3: Refactor `common.nix`

**New Structure** (`home/modules/desktop/common.nix`):
```nix
{ config, lib, pkgs, desktop, userSettings, ... }:
{
  # Only truly universal packages
  home.packages = with pkgs; [
    libnotify      # Used by all DEs for notifications
    playerctl      # Media control (universal)
    brightnessctl  # Brightness (universal, harmless on desktop)
    pamixer        # Audio control (universal)
  ];

  xdg.enable = true;

  home.sessionVariables = {
    TERMINAL = userSettings.term;
    BROWSER = userSettings.browser;
  };

  # NO hardcoded services - everything dispatched via desktop options
}
```

**Key Changes**:
- ❌ Remove `wl-clipboard`, `cliphist`, `grim`, `slurp`, `swappy`
- ❌ Remove `services.mako` (move to `notifications/mako.nix`)
- ✅ Keep only universal tools that work across all DEs

### Phase 4: Move Notifications to Module Directory

**Current**: `services.mako` is in `common.nix` with conditional enablement

**New Structure**:
```
home/modules/desktop/notifications/
├── mako.nix         # Wayland notification daemon
├── dunst.nix        # Alternative notification daemon
└── none.nix         # For DEs with built-in notifications
```

**Migration**:
- Remove `services.mako` from `common.nix`
- Create `notifications/mako.nix` with mako configuration
- Update dispatcher to import from `notificationModules`

### Phase 5: Session Module Cleanup

**File**: `home/modules/desktop/sessions/hyprland.nix`

**Remove**:
```nix
# Current hardcoded packages
home.packages = [
  clipman  # REMOVE - handled by clipboard module
  # ... keep only hyprland-specific packages
];

# Current hardcoded exec-once
exec-once = [
  "wl-paste --type text --watch clipman store &"   # REMOVE
  "wl-paste --type image --watch clipman store &"  # REMOVE
  # ... clipboard startup handled by clipboard module
];

# Current hardcoded keybinds
bind = [
  ",Print, exec, screenshot --copy"  # REMOVE or use abstraction
  # ... screenshot handled by screenshot module
];
```

**Result**: Session modules only contain compositor-specific configuration (window rules, animations, layout settings), NOT tool integrations.

---

## Implementation Phases

### ✅ Phase 0: Current State (Completed)
- [x] Modular bar system
- [x] Modular lock system
- [x] Modular idle system
- [x] Notifications option added
- [x] Session-based defaults and resolver

### 🔄 Phase 1: Clipboard Modularization
**Priority**: High (most common conflict with GNOME)

**Step-by-Step Implementation**:

1. **Create clipboard module directory**:
   ```bash
   mkdir -p home/modules/desktop/clipboard
   ```

2. **Create `clipboard/clipman.nix`**:
   - See detailed implementation in section 2.1 above
   - Includes systemd service for auto-start
   - Provides standardized shell aliases

3. **Create `clipboard/cliphist.nix`**:
   - Alternative clipboard manager
   - Same interface as clipman module
   
4. **Create `clipboard/none.nix`**:
   - Empty module (just `{ ... }: {}`)

5. **Update `lib/desktop.nix`**:
   ```nix
   sessionDefaults = {
     hyprland = {
       # ... existing options
       clipboard = "clipman";  # ADD THIS
     };
     sway = {
       # ... existing options  
       clipboard = "clipman";  # ADD THIS
     };
     gnome = {
       # ... existing options
       clipboard = "none";     # ADD THIS
     };
   };

   # In resolveDesktop function, add:
   clipboard = if desktop.clipboard or null != null 
               then desktop.clipboard 
               else defaults.clipboard;
   ```

6. **Update `home/modules/desktop/default.nix`**:
   ```nix
   let
     # ... existing lookup tables
     
     clipboardModules = {
       clipman = ./clipboard/clipman.nix;
       cliphist = ./clipboard/cliphist.nix;
       none = ./clipboard/none.nix;
     };
   in {
     imports = lib.optionals enabled ([
       ./common.nix
     ] ++ lib.optional (sessionModules ? ${desktop.session}) sessionModules.${desktop.session}
       ++ lib.optional (barModules ? ${desktop.bar}) barModules.${desktop.bar}
       ++ lib.optional (lockModules ? ${desktop.lock}) lockModules.${desktop.lock}
       ++ lib.optional (idleModules ? ${desktop.idle}) idleModules.${desktop.idle}
       ++ lib.optional (clipboardModules ? ${desktop.clipboard}) clipboardModules.${desktop.clipboard}  # ADD THIS
     );
   }
   ```

7. **Remove from `home/modules/desktop/common.nix`**:
   ```nix
   # DELETE THESE LINES:
   wl-clipboard
   cliphist
   ```

8. **Remove from `home/modules/desktop/sessions/hyprland.nix`**:
   ```nix
   # DELETE FROM home.packages:
   clipman
   
   # DELETE FROM exec-once array:
   "wl-paste --type text --watch clipman store &"
   "wl-paste --type image --watch clipman store &"
   ```

9. **Remove from `home/modules/desktop/sessions/sway.nix`**:
   ```nix
   # DELETE FROM home.packages (line 48):
   clipman
   
   # DELETE clipboard startup from config (if present)
   ```

10. **Update host configs** (optional - defaults work):
    ```nix
    # In hosts/workstation.nix, hosts/lenovo-yoga-pro-7.nix:
    desktop = {
      # ... existing options
      clipboard = null;  # null = use session default (clipman)
    };
    ```

**Testing Phase 1**:
```bash
# Build
nixos-rebuild build --flake .#workstation

# Switch
sudo nixos-rebuild switch --flake .#workstation

# Logout and login

# Test clipboard
echo "test" | wl-copy
clipboard-history  # Should open rofi with clipboard history

# Check systemd service
systemctl --user status clipman
```

**Files Modified in Phase 1**:
- `lib/desktop.nix` - Add clipboard option
- `home/modules/desktop/default.nix` - Add dispatcher
- `home/modules/desktop/clipboard/clipman.nix` - CREATE
- `home/modules/desktop/clipboard/cliphist.nix` - CREATE  
- `home/modules/desktop/clipboard/none.nix` - CREATE
- `home/modules/desktop/common.nix` - Remove packages
- `home/modules/desktop/sessions/hyprland.nix` - Remove clipboard code
- `home/modules/desktop/sessions/sway.nix` - Remove clipboard code

### 🔄 Phase 2: Screenshot Modularization
**Priority**: High (conflicts with GNOME screenshot)

**Step-by-Step Implementation**:

1. **Create screenshot module directory**:
   ```bash
   mkdir -p home/modules/desktop/screenshot
   ```

2. **Create `screenshot/grimblast.nix`**:
   - See detailed implementation in section 2.2 above
   - Provides `screenshot` command with --copy, --save, --swappy options
   - Uses grimblast (Hyprland-optimized)

3. **Create `screenshot/grim.nix`**:
   - Generic Wayland screenshot using grim + slurp
   - Same `screenshot` command interface
   
4. **Create `screenshot/none.nix`**:
   - Empty module for GNOME (uses gnome-screenshot)

5. **Update `lib/desktop.nix`**:
   ```nix
   sessionDefaults = {
     hyprland = {
       # ... existing options
       screenshot = "grimblast";  # ADD THIS
     };
     sway = {
       # ... existing options  
       screenshot = "grim";       # ADD THIS
     };
     gnome = {
       # ... existing options
       screenshot = "none";       # ADD THIS
     };
   };

   # In resolveDesktop function, add:
   screenshot = if desktop.screenshot or null != null 
                then desktop.screenshot 
                else defaults.screenshot;
   ```

6. **Update `home/modules/desktop/default.nix`**:
   ```nix
   screenshotModules = {
     grimblast = ./screenshot/grimblast.nix;
     grim = ./screenshot/grim.nix;
     none = ./screenshot/none.nix;
   };

   imports = lib.optionals enabled ([
     # ... existing imports
     ++ lib.optional (screenshotModules ? ${desktop.screenshot}) screenshotModules.${desktop.screenshot}
   );
   ```

7. **Remove from `home/modules/desktop/common.nix`**:
   ```nix
   # DELETE THESE LINES:
   grim
   slurp
   swappy
   ```

8. **Remove from `home/modules/desktop/bars/hyprpanel.nix`**:
   ```nix
   # DELETE FROM home.packages (line 50):
   grimblast
   
   # Keep wf-recorder if needed for screen recording
   ```

9. **Session keybinds already reference `screenshot` command** - no changes needed!
   - `sessions/hyprland.nix` lines 269-271 already use `screenshot --copy` etc.
   - These will now work with whichever screenshot module is enabled

**Testing Phase 2**:
```bash
# Build and switch
nixos-rebuild build --flake .#workstation
sudo nixos-rebuild switch --flake .#workstation

# Logout and login

# Test screenshot commands
screenshot --copy     # Should let you select area and copy to clipboard
screenshot --save     # Should save to ~/Pictures/Screenshots/
screenshot --swappy   # Should open swappy editor

# Test keybinds
# PrintScreen          -> screenshot --copy
# Super+PrintScreen    -> screenshot --save  
# Super+Shift+PrintScreen -> screenshot --swappy
```

**Files Modified in Phase 2**:
- `lib/desktop.nix` - Add screenshot option
- `home/modules/desktop/default.nix` - Add dispatcher
- `home/modules/desktop/screenshot/grimblast.nix` - CREATE
- `home/modules/desktop/screenshot/grim.nix` - CREATE
- `home/modules/desktop/screenshot/none.nix` - CREATE
- `home/modules/desktop/common.nix` - Remove grim, slurp, swappy
- `home/modules/desktop/bars/hyprpanel.nix` - Remove grimblast

### 🔄 Phase 3: Applets Modularization
**Priority**: Medium (mostly redundancy, less severe conflicts)

1. Create `home/modules/desktop/applets/` directory
2. Create `wayland.nix`, `none.nix` modules
3. Add `applets` to `lib/desktop.nix` session defaults
4. Update dispatcher
5. Remove applet services from `bars/waybar.nix`

**Files to Modify**:
- `lib/desktop.nix` - Add applets defaults
- `home/modules/desktop/default.nix` - Add applets dispatcher
- `home/modules/desktop/bars/waybar.nix` - Remove applet services

### 🔄 Phase 4: Redshift Modularization
**Priority**: Medium (GNOME has Night Light, creates conflict)

1. Create `home/modules/desktop/redshift/` directory
2. Create `gammastep.nix`, `redshift.nix`, `none.nix` modules
3. Add `redshift` to `lib/desktop.nix` session defaults
4. Update dispatcher
5. Remove gammastep from `bars/waybar.nix`

**Files to Modify**:
- `lib/desktop.nix` - Add redshift defaults
- `home/modules/desktop/default.nix` - Add redshift dispatcher
- `home/modules/desktop/bars/waybar.nix` - Remove gammastep script and module

### 🔄 Phase 5: Notifications Module Directory
**Priority**: Low (already properly abstracted, just reorganization)

1. Create `home/modules/desktop/notifications/` directory
2. Create `mako.nix`, `dunst.nix`, `none.nix` modules
3. Move mako config from `common.nix` to `notifications/mako.nix`
4. Update dispatcher to import from directory

**Files to Modify**:
- `home/modules/desktop/default.nix` - Add notification dispatcher
- `home/modules/desktop/common.nix` - Remove services.mako

### 🔄 Phase 6: Final Common.nix Cleanup
**Priority**: Low (cleanup phase)

1. Review remaining packages in `common.nix`
2. Document which are universal vs session-specific
3. Consider creating `wayland-common.nix` for Wayland sessions if needed
4. Add comments explaining why each package is in common

---

## Benefits After Completion

### ✅ Seamless DE Switching
```nix
# Switch from Hyprland to GNOME - just change one line!
desktop.session = "gnome";  # Everything else auto-configures
```

### ✅ No Conflicts
- GNOME won't have redundant Wayland tools
- No competing clipboard managers
- No competing screenshot tools
- No competing notification daemons

### ✅ Consistent Architecture
Every component follows the same pattern:
1. Option in `lib/desktop.nix`
2. Module directory with implementations
3. Dispatcher in `default.nix`
4. Session-specific defaults

### ✅ Easy Extensibility
Adding new tools is straightforward:
1. Create module file
2. Add to dispatcher lookup table
3. Set session defaults
4. Done!

### ✅ Override Flexibility
```nix
desktop = {
  session = "hyprland";
  clipboard = "cliphist";  # Override default clipman
  screenshot = "grim";     # Override default grimblast
  # ... other overrides
};
```

## Testing Strategy

### Test Matrix

| Session | Clipboard | Screenshot | Notifications | Applets | Redshift |
|---------|-----------|------------|---------------|---------|----------|
| hyprland | clipman | grimblast | hyprpanel | wayland | gammastep |
| sway | clipman | grim | mako | wayland | gammastep |
| gnome | none | none | none | none | none |

### Per-Phase Testing

**Build Phase**:
```bash
nixos-rebuild build --flake .#workstation
# Look for evaluation errors
# Check that correct modules are being imported
```

**Switch Phase**:
```bash
sudo nixos-rebuild switch --flake .#workstation
# Look for activation errors
# Check systemd service failures
```

**Runtime Testing**:
```bash
# 1. Logout and login to apply changes

# 2. Check processes are running
ps aux | grep -E "clipman|mako|hyprpanel"

# 3. Check systemd services
systemctl --user status clipman
systemctl --user status mako

# 4. Test functionality
echo "test" | wl-copy
clipboard-history

screenshot --copy
screenshot --save

gamma-toggle
```

### Integration Testing

**Test Scenario 1: Hyprland → Sway**
```bash
# In hosts/workstation.nix, change:
desktop.session = "sway";

# Build and switch
sudo nixos-rebuild switch --flake .#workstation

# Verify:
# - clipman still works (same in both)
# - screenshot switches from grimblast to grim
# - notifications switches from hyprpanel to mako
# - No leftover hyprpanel processes
```

**Test Scenario 2: Hyprland → GNOME**
```bash
# In hosts/workstation.nix, change:
desktop.session = "gnome";

# Build and switch
sudo nixos-rebuild switch --flake .#workstation

# Verify:
# - No clipman installed or running
# - No grimblast/grim installed
# - No mako running
# - GNOME's built-in tools work (Super+V for clipboard, PrintScreen for screenshot)
# - No conflicts or duplicate processes
```

**Test Scenario 3: Override Defaults**
```bash
# In hosts/workstation.nix:
desktop = {
  session = "hyprland";
  clipboard = "cliphist";     # Override default clipman
  screenshot = "grim";        # Override default grimblast
  notifications = "mako";     # Override default hyprpanel
};

# Verify overrides work correctly
```

### Validation Checklist (After Each Phase)

- [ ] Build succeeds without errors
- [ ] Switch succeeds without activation errors
- [ ] Correct packages are installed (check with `nix-store -q --references /run/current-system`)
- [ ] Correct services are running (check with `systemctl --user list-units`)
- [ ] No duplicate processes (e.g., two clipboard managers)
- [ ] Functionality works (clipboard, screenshot, etc.)
- [ ] No errors in `journalctl --user -xe`
- [ ] Session switch works without manual cleanup
- [ ] Keybinds still work after modularization

### Debugging Common Issues

**Issue**: Module not found error
```
error: attribute 'clipman' missing
```
**Solution**: Check lookup table in `default.nix` includes the module, and the file exists

**Issue**: Duplicate services running
```
two instances of clipman running
```
**Solution**: Check that old hardcoded services are removed from session modules

**Issue**: Command not found
```
bash: screenshot: command not found
```
**Solution**: Check that screenshot module is being imported and provides the command in PATH

**Issue**: Systemd service fails to start
```
systemctl --user status clipman
● clipman.service - Clipman clipboard manager
   Loaded: loaded
   Active: failed
```
**Solution**: Check service definition in module, ensure dependencies are available

---

## Migration Path

### For Existing Configs

**Backward Compatibility**: All changes maintain backward compatibility through defaults.

**Explicit Migration** (optional):
```nix
# Old: implicit defaults
desktop.session = "hyprland";

# New: explicit (same behavior)
desktop = {
  session = "hyprland";
  clipboard = null;      # Uses session default (clipman)
  screenshot = null;     # Uses session default (grimblast)
  notifications = null;  # Uses session default (hyprpanel)
  applets = null;        # Uses session default (wayland)
  redshift = null;       # Uses session default (gammastep)
};
```

**No Breaking Changes**: Existing configs continue to work without modification.

---

## Success Criteria

- [ ] All Wayland-specific packages removed from `common.nix`
- [ ] All services conditionally enabled via desktop options
- [ ] Clean switch between Hyprland, Sway, and GNOME with zero conflicts
- [ ] Session modules contain ONLY compositor-specific config (window rules, keybinds, animations)
- [ ] Bar modules contain ONLY bar-specific config (styling, modules, layout)
- [ ] Every component follows the dispatcher pattern
- [ ] Documentation updated for all new options
- [ ] All tests pass for each session type
- [ ] No duplicate processes when switching sessions
- [ ] No manual cleanup required when switching sessions
- [ ] Each module can be independently enabled/disabled
- [ ] Override system works (can mix-and-match components)

---

## Potential Issues & Solutions

### Issue 1: Circular Dependencies

**Problem**: Screenshot module needs wl-clipboard, but clipboard module also provides it.

**Solution**: 
- Screenshot module should include wl-clipboard in its own dependencies
- NixOS deduplicates packages automatically
- Each module should be self-contained

### Issue 2: Session-Specific Commands

**Problem**: `grimblast` only works on Hyprland, will fail on Sway.

**Solution**: 
- Each screenshot module provides the same `screenshot` command interface
- The implementation differs but the interface is consistent
- Session keybinds call generic `screenshot` command, not tool-specific commands

### Issue 3: Bar Integration with External Tools

**Problem**: Waybar wants to show gammastep status, but gammastep might not be enabled.

**Solution**:
- Bar module checks if command exists before showing widget
- Use `lib.optionalAttrs` to conditionally include bar modules
- Example:
  ```nix
  modules-right = [
    "pulseaudio"
  ] ++ lib.optional (desktop.redshift != "none") "custom/gammastep";
  ```

### Issue 4: systemd Service Conflicts

**Problem**: Both clipman module and session module try to start clipboard daemon.

**Solution**:
- Only clipboard module should start services
- Session modules should never start tool daemons
- Use `systemd.user.services` in tool modules, not exec-once in session modules

### Issue 5: PATH Issues with Custom Scripts

**Problem**: `screenshot` command not in PATH when called from keybind.

**Solution**:
- Use `pkgs.writeShellScriptBin` which automatically adds to PATH
- Ensure script is in `home.packages`
- Session modules automatically get access to all packages

### Issue 6: GNOME Session Doesn't Need Wayland Tools

**Problem**: Even with `clipboard = "none"`, Wayland packages might leak in.

**Solution**:
- `none.nix` modules must be truly empty: `{ ... }: {}`
- Double-check `common.nix` has no Wayland-specific packages
- Use `lib.mkIf (desktop.session != "gnome")` for Wayland-specific global settings

### Issue 7: Override Conflicts

**Problem**: User sets `session = "gnome"` but also `clipboard = "clipman"` (incompatible).

**Solution**:
- Allow it - user explicitly wants this
- Add validation warnings in future if needed
- Document recommended configurations
- Trust users know what they're doing with explicit overrides

### Issue 8: Missing Dependencies

**Problem**: Screenshot module uses `rofi` but it's not installed.

**Solution**:
- If a module requires another component, document it
- Consider making rofi part of common.nix (it's fairly universal)
- Or include it in modules that need it
- Use `lib.mkIf` to conditionally include features

---

## Next Steps

1. **Review and approve this plan** ✓
2. **Prioritize phases**: Clipboard → Screenshot → Applets → Redshift → Notifications
3. **Implement Phase 1** (Clipboard) as proof of concept
4. **Test thoroughly** with Hyprland and GNOME  
5. **Iterate** through remaining phases
6. **Document** new desktop options in README

---

## Quick Reference

### All Desktop Options (After Completion)

```nix
# In hosts/workstation.nix:
desktop = {
  # Core session selection
  session = "hyprland";           # hyprland | sway | gnome | none
  
  # Component selection (null = use session default)
  bar = null;                     # hyprpanel | waybar | none
  lock = null;                    # hyprlock | swaylock | loginctl | none
  idle = null;                    # hypridle | swayidle | none
  notifications = null;           # hyprpanel | mako | dunst | none
  clipboard = null;               # clipman | cliphist | none
  screenshot = null;              # grimblast | grim | none
  applets = null;                 # wayland | none
  redshift = null;                # gammastep | redshift | none
  
  # Session-specific configuration
  monitors = [ ... ];
  workspaceRules = [ ... ];
  extraConfig = "";
};
```

### Session Defaults Quick Reference

| Session | bar | lock | idle | notifications | clipboard | screenshot | applets | redshift |
|---------|-----|------|------|---------------|-----------|------------|---------|----------|
| **hyprland** | hyprpanel | hyprlock | hypridle | hyprpanel | clipman | grimblast | wayland | gammastep |
| **sway** | waybar | swaylock | swayidle | mako | clipman | grim | wayland | gammastep |
| **gnome** | none | loginctl | none | none | none | none | none | none |

### Common Commands (After Modularization)

```bash
# Clipboard
clipboard-history       # Open clipboard history in rofi
clipboard-clear         # Clear clipboard history

# Screenshots
screenshot --copy       # Copy area to clipboard
screenshot --save       # Save area to ~/Pictures/Screenshots/
screenshot --swappy     # Open area in swappy editor

# Redshift
gamma-toggle           # Toggle night light on/off

# System (existing)
lock-session           # Lock screen (uses configured lock)
```

### Module Directory Structure (Final)

```
home/modules/desktop/
├── default.nix              # Main dispatcher
├── common.nix               # Universal packages only
├── sessions/
│   ├── hyprland.nix
│   ├── sway.nix
│   └── gnome.nix
├── bars/
│   ├── waybar.nix
│   ├── hyprpanel.nix
│   └── rofi/                # Shared rofi config
├── lock/
│   ├── hyprlock.nix
│   └── swaylock.nix
├── idle/
│   ├── hypridle.nix
│   └── swayidle.nix
├── notifications/           # NEW
│   ├── mako.nix
│   ├── dunst.nix
│   └── none.nix
├── clipboard/               # NEW
│   ├── clipman.nix
│   ├── cliphist.nix
│   └── none.nix
├── screenshot/              # NEW
│   ├── grimblast.nix
│   ├── grim.nix
│   └── none.nix
├── applets/                 # NEW
│   ├── wayland.nix
│   └── none.nix
└── redshift/                # NEW
    ├── gammastep.nix
    ├── redshift.nix
    └── none.nix
```

### Example Configurations

**Minimal Hyprland Setup**:
```nix
desktop.session = "hyprland";
# All other options use defaults
```

**Custom Hyprland Setup**:
```nix
desktop = {
  session = "hyprland";
  clipboard = "cliphist";     # Override: use cliphist instead of clipman
  bar = "waybar";             # Override: use waybar instead of hyprpanel
  # Other options use defaults
};
```

**GNOME Setup**:
```nix
desktop.session = "gnome";
# Everything automatically set to "none" (uses GNOME built-ins)
```

**Mixed Setup** (Advanced):
```nix
desktop = {
  session = "sway";
  bar = "hyprpanel";          # Use hyprpanel with Sway
  notifications = "mako";     # Use mako (not hyprpanel's AGS notifications)
  clipboard = "cliphist";     # Use cliphist instead of clipman
};
```

---

*Last Updated: $(date)*
*Architecture Version: 2.0 (Proposed)*
*Current Status: Planning Phase*
