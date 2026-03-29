# Modular Desktop/Session Switching (NixOS + Home Manager)

**Created:** 2025-02-01
**Status:** Ready for implementation

---

## Summary

Refactor desktop/session configuration so each host can independently select:
- Session (Hyprland/Sway/GNOME)
- Bar (Hyprpanel/Waybar/none)
- Lock screen (Hyprlock/Swaylock/loginctl)
- Idle daemon (Hypridle/Swayidle/none)
- Display manager (SDDM/GDM/none)

All options are per-host configurable. Shared theming (Stylix) flows into all components.

---

## Design Principles

1. **Pure data in `hosts/`** - Host files contain only data (attrsets), no imports or modules
2. **Modules consume data** - `systems/` and `home/` modules read host data, apply logic
3. **Lookup tables over conditionals** - Use attrset lookups instead of if/else chains
4. **Defaults with overrides** - Sensible defaults, only specify what differs
5. **No duplicate logic** - Share types/defaults via `lib/`

---

## Example: Target Configuration

### Host Data (`hosts/workstation.nix`)

```nix
# Pure data - no imports, no lib, no pkgs
{
  hostname = "workstation";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";          # Optional: null = auto from session
    lock = "hyprlock";          # Optional: null = auto from session
    idle = "hypridle";          # Optional: null = auto from session

    monitors = [
      "DP-1,3440x1440@144,0x0,1"
      "DP-2,2560x1440@144,3440x0,1"
    ];

    workspaceRules = [
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-1"
      "3, monitor:DP-1"
      "4, monitor:DP-2, default:true"
      "5, monitor:DP-2"
    ];
  };

  hardware = {
    gpu = "nvidia";
    logitech = true;
  };
}
```

### Flake (`flake.nix`)

```nix
let
  # Import all host configs
  hosts = {
    workstation = import ./hosts/workstation.nix;
    lenovo-yoga-pro-7 = import ./hosts/lenovo-yoga-pro-7.nix;
    hp-server = import ./hosts/hp-server.nix;
  };

  users = {
    henhal = { /* user settings */ };
    henhal-dev = { /* user settings */ };
  };
in {
  nixosConfigurations = {
    workstation = mkNixosSystem {
      hostConfig = hosts.workstation;
      userSettings = users.henhal;
    };

    lenovo-yoga-pro-7 = mkNixosSystem {
      hostConfig = hosts.lenovo-yoga-pro-7;
      userSettings = users.henhal;
    };

    hp-server = mkNixosSystem {
      hostConfig = hosts.hp-server;
      userSettings = users.henhal-dev;
    };
  };
}
```

No more `windowManager` variable. No more conditional imports scattered everywhere.

---

## Current Issues (Analysis)

### 1. Duplicated WM Conditionals
The same if/else chain appears in 3 places:
- `systems/workstation/configuration.nix:10-26`
- `systems/lenovo-yoga-pro-7/configuration.nix:10-25`
- `users/henhal/home.nix:31-46`

### 2. Hardcoded Values
| Value | Location | Should Be |
|-------|----------|-----------|
| `vivaldi` | hyprland.nix:63,170,252 | `userSettings.browser` |
| `zen` | sway.nix:199,217 | `userSettings.browser` |
| `kitty` | multiple | `userSettings.term` |
| `"henhal"` | sddm.nix autologin | `userSettings.username` |
| `"no"` keyboard | hyprland.nix:266 | `my.desktop.xkb.layout` |

### 3. Monolithic Files
- `hyprland.nix`: 22KB with monitors+keybinds+rules+per-host configs all mixed
- `waybar/default.nix`: 536 lines with hardcoded Catppuccin theme

### 4. Inconsistent Theming
- Rofi: Uses `config.lib.stylix.colors` ✓
- Waybar: Hardcoded Catppuccin, ignores Stylix ✗
- Hyprpanel: Custom theme mapping, not Stylix ✗
- SDDM: Hardcoded "Matrix green" palette ✗

### 5. No Component Selection
- Bar is tied to session (hyprland → hyprpanel, sway → waybar)
- Lock is guessed wrong in rofi (`windowManager ? "hyprland"` default)
- No way to run Hyprland with Waybar or Sway with Hyprpanel

### 6. Typo
- `nixos/modules/window-manager/hyrpland.nix` → should be `hyprland.nix`

---

## Target Directory Structure

```
.
├── flake.nix                        # Minimal: imports hosts, defines nixosConfigurations
│
├── hosts/                           # Pure data files (no imports/modules)
│   ├── workstation.nix              # { hostname, desktop, hardware }
│   ├── lenovo-yoga-pro-7.nix
│   └── hp-server.nix
│
├── lib/                             # Shared functions and types
│   ├── theme.nix                    # Stylix theme derivation
│   ├── desktop.nix                  # Desktop types, defaults, resolvers
│   └── mk-nixos-system.nix          # System builder function
│
├── systems/                         # NixOS per-host modules (hardware, services)
│   ├── workstation/
│   │   ├── configuration.nix        # Uses hostConfig for hardware decisions
│   │   └── hardware-configuration.nix
│   ├── lenovo-yoga-pro-7/
│   │   └── ...
│   └── hp-server/
│       └── ...
│
├── nixos/                           # NixOS shared modules
│   ├── default.nix
│   └── modules/
│       ├── desktop/
│       │   ├── default.nix          # Dispatcher (uses lookup tables)
│       │   ├── common.nix           # xkb, dconf, portals
│       │   ├── sessions/
│       │   │   ├── hyprland.nix
│       │   │   ├── sway.nix
│       │   │   └── gnome.nix
│       │   └── display-managers/
│       │       ├── sddm.nix
│       │       └── gdm.nix
│       ├── theme/
│       │   └── stylix.nix
│       └── window-manager/          # DEPRECATED (Phase 6: delete)
│
├── home/                            # Home Manager shared modules
│   └── modules/
│       ├── desktop/
│       │   ├── default.nix          # Dispatcher (uses lookup tables)
│       │   ├── common.nix           # Shared packages, env vars
│       │   ├── sessions/
│       │   │   ├── hyprland.nix
│       │   │   ├── sway.nix
│       │   │   └── gnome.nix
│       │   ├── bars/
│       │   │   ├── waybar.nix
│       │   │   └── hyprpanel.nix
│       │   ├── lock/
│       │   │   ├── hyprlock.nix
│       │   │   └── swaylock.nix
│       │   ├── idle/
│       │   │   ├── hypridle.nix
│       │   │   └── swayidle.nix
│       │   └── launchers/
│       │       └── rofi.nix
│       ├── themes/
│       │   └── stylix/
│       └── window-manager/          # DEPRECATED (Phase 6: delete)
│
└── users/                           # Per-user Home Manager config
    └── henhal/
        └── home.nix                 # User apps, dotfiles (not desktop)
```

### Key Separation

| Directory | Contains | Imports modules? | Per-host? |
|-----------|----------|------------------|-----------|
| `hosts/` | Pure data (attrsets) | No | Yes |
| `systems/` | NixOS hardware/services | Yes | Yes |
| `nixos/modules/` | Shared NixOS modules | Yes | No |
| `home/modules/` | Shared HM modules | Yes | No |
| `users/` | User-specific HM config | Yes | No |
| `lib/` | Functions, types, defaults | No | No |

---

## Shared Library (`lib/desktop.nix`)

Centralize types, defaults, and resolver logic. Both NixOS and HM modules use this.

```nix
# lib/desktop.nix
{ lib }:
rec {
  # Session defaults - what each session uses by default
  sessionDefaults = {
    hyprland = { bar = "hyprpanel"; lock = "hyprlock"; idle = "hypridle"; dm = "sddm"; };
    sway     = { bar = "waybar";    lock = "swaylock"; idle = "swayidle"; dm = "sddm"; };
    gnome    = { bar = "none";      lock = "loginctl"; idle = "none";     dm = "gdm"; };
    none     = { bar = "none";      lock = "none";     idle = "none";     dm = "none"; };
  };

  # Resolve null values to session defaults
  resolve = { session, bar, lock, idle, ... }@desktop:
    let
      defaults = sessionDefaults.${session} or sessionDefaults.none;
    in {
      inherit session;
      bar = if bar != null then bar else defaults.bar;
      lock = if lock != null then lock else defaults.lock;
      idle = if idle != null then idle else defaults.idle;
      dm = defaults.dm;
      # Pass through other fields (monitors, workspaceRules, etc.)
    } // (removeAttrs desktop [ "session" "bar" "lock" "idle" ]);

  # Module lookup tables
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

  dmModules = {
    sddm = ./display-managers/sddm.nix;
    gdm = ./display-managers/gdm.nix;
  };
}
```

### Per-Session Defaults Table

| Session | Bar | Lock | Idle | Display Manager |
|---------|-----|------|------|-----------------|
| hyprland | hyprpanel | hyprlock | hypridle | sddm |
| sway | waybar | swaylock | swayidle | sddm |
| gnome | none | loginctl | none | gdm |
| none | none | none | none | none |

### Override Example

```nix
# hosts/workstation.nix
{
  desktop = {
    session = "hyprland";
    bar = "waybar";      # Override: waybar instead of default hyprpanel
    # lock and idle remain null → use defaults (hyprlock, hypridle)
  };
}
```

---

## Implementation Phases

### Phase 0: Fix Known Correctness Bugs

**Objective:** Remove landmines before refactor.

#### 0.1 Fix rofi lock command selection

**Current (broken):**
```nix
# home/modules/window-manager/rofi/default.nix:6-11
lockCommand =
  if windowManager == "hyprland"
  then "hyprlock"
  else if windowManager == "sway"
  then "swaylock"
  else "hyprlock"; # Wrong default for unknown WMs
```

**Fix:**
```nix
lockCommand =
  if windowManager == "hyprland" then "hyprlock"
  else if windowManager == "sway" then "swaylock"
  else if windowManager == "gnome" then "loginctl lock-session"
  else "loginctl lock-session";
```

#### 0.2 Fix sway.nix bugs

```nix
# Fix missing $ in interpolation
terminal = "${userSettings.term}";  # was: "{userSettings.term}"

# Fix hardcoded browser
exec ${userSettings.browser}  # was: exec zen
```

#### 0.3 Fix sddm.nix hardcoded autologin

```nix
services.displayManager.autoLogin.user = userSettings.username;  # was: "henhal"
```

#### 0.4 Rename typo

```bash
mv nixos/modules/window-manager/hyrpland.nix nixos/modules/window-manager/hyprland.nix
# Update imports in systems/*/configuration.nix
```

#### 0.5 Fix hyprland.nix hardcoded apps

```nix
exec-once = ${userSettings.browser}  # was: vivaldi
```

**Acceptance Criteria:**
- [ ] `nixos-rebuild build --flake .#workstation` succeeds
- [ ] `nixos-rebuild build --flake .#lenovo-yoga-pro-7` succeeds
- [ ] Sway's rofi uses swaylock (not hyprlock)
- [ ] No hardcoded "henhal" in sddm.nix

---

### Phase 1: Create Hosts Directory + Shared Libraries

**Objective:** Establish the new structure with pure data host files.

#### 1.1 Create `hosts/` directory with host data files

```nix
# hosts/workstation.nix
{
  hostname = "workstation";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";
    lock = null;                      # null = use session default
    idle = null;

    monitors = [
      "DP-1,3440x1440@144,0x0,1"
      "DP-2,2560x1440@144,3440x0,1"
    ];

    workspaceRules = [
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-1"
      "3, monitor:DP-1"
      "4, monitor:DP-2, default:true"
      "5, monitor:DP-2"
    ];
  };

  hardware = {
    gpu = "nvidia";
    logitech = true;
  };
}
```

```nix
# hosts/lenovo-yoga-pro-7.nix
{
  hostname = "yoga-pro-7";

  desktop = {
    session = "sway";
    bar = "waybar";
    lock = null;
    idle = null;

    monitors = [
      "eDP-1,2880x1800@120,0x0,1.5"
    ];

    # Sway-specific output config
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
      }
    '';
  };

  hardware = {
    gpu = "amd";
  };
}
```

```nix
# hosts/hp-server.nix
{
  hostname = "hp-server";

  desktop = {
    session = "none";
  };

  hardware = {};
}
```

#### 1.2 Create `lib/desktop.nix`

```nix
# lib/desktop.nix
{ lib }:
rec {
  # Per-session defaults
  sessionDefaults = {
    hyprland = { bar = "hyprpanel"; lock = "hyprlock"; idle = "hypridle"; dm = "sddm"; };
    sway     = { bar = "waybar";    lock = "swaylock"; idle = "swayidle"; dm = "sddm"; };
    gnome    = { bar = "none";      lock = "loginctl"; idle = "none";     dm = "gdm"; };
    none     = { bar = "none";      lock = "none";     idle = "none";     dm = "none"; };
  };

  # Resolve null values to session defaults
  resolveDesktop = desktop:
    let
      session = desktop.session or "none";
      defaults = sessionDefaults.${session};
    in desktop // {
      bar = if desktop.bar or null != null then desktop.bar else defaults.bar;
      lock = if desktop.lock or null != null then desktop.lock else defaults.lock;
      idle = if desktop.idle or null != null then desktop.idle else defaults.idle;
      dm = defaults.dm;
    };
}
```

#### 1.3 Create `lib/theme.nix`

```nix
# lib/theme.nix
{ pkgs, userSettings }:
let
  cfg = userSettings.stylixTheme;

  schemes = {
    "catppuccin-mocha" = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    "catppuccin-macchiato" = "${pkgs.base16-schemes}/share/themes/catppuccin-macchiato.yaml";
    "gruvbox-dark-hard" = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-hard.yaml";
    "nord" = "${pkgs.base16-schemes}/share/themes/nord.yaml";
    "dracula" = "${pkgs.base16-schemes}/share/themes/dracula.yaml";
    "rose-pine-moon" = "${pkgs.base16-schemes}/share/themes/rose-pine-moon.yaml";
  };
in {
  base16Scheme = schemes.${cfg.scheme} or (throw "Unknown scheme: ${cfg.scheme}");
  image = ../assets/wallpapers/${cfg.wallpaper};

  cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  fonts = {
    monospace = { package = pkgs.nerd-fonts.hack; name = "Hack Nerd Font"; };
    sansSerif = { package = pkgs.inter; name = "Inter"; };
    serif = { package = pkgs.noto-fonts; name = "Noto Serif"; };
    sizes = { applications = 11; desktop = 11; popups = 11; terminal = 12; };
  };
}
```

#### 1.4 Create `lib/mk-nixos-system.nix`

```nix
# lib/mk-nixos-system.nix
{ nixpkgs, home-manager, stylix, lanzaboote, ... }@inputs:
{ hostConfig, userSettings, extraModules ? [] }:

let
  system = "x86_64-linux";
  desktopLib = import ./desktop.nix { inherit (nixpkgs) lib; };
  resolvedDesktop = desktopLib.resolveDesktop (hostConfig.desktop or { session = "none"; });
in
nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit userSettings hostConfig inputs;
    desktop = resolvedDesktop;  # Pre-resolved, ready to use
  };

  modules = [
    stylix.nixosModules.stylix
    lanzaboote.nixosModules.lanzaboote
    ../systems/${hostConfig.hostname}/configuration.nix
    ../nixos/modules/desktop/default.nix
    ../nixos/modules/theme/stylix.nix

    # Home Manager integration
    home-manager.nixosModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = false;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {
          inherit userSettings hostConfig inputs;
          desktop = resolvedDesktop;
        };
        users.${userSettings.username} = import ../users/${userSettings.username}/home.nix;
      };
    }

    # Base config
    ({ pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;
      networking.hostName = hostConfig.hostname;
      time.timeZone = "Europe/Oslo";
      i18n.defaultLocale = "en_US.UTF-8";
      system.stateVersion = userSettings.stateVersion;
    })
  ] ++ extraModules;
}
```

#### 1.5 Update `flake.nix`

```nix
# flake.nix
{
  inputs = { /* unchanged */ };

  outputs = { nixpkgs, home-manager, stylix, lanzaboote, ... }@inputs:
  let
    # Host configs (pure data)
    hosts = {
      workstation = import ./hosts/workstation.nix;
      lenovo-yoga-pro-7 = import ./hosts/lenovo-yoga-pro-7.nix;
      hp-server = import ./hosts/hp-server.nix;
    };

    # User configs
    users = {
      henhal = {
        username = "henhal";
        name = "Henrik";
        email = "henhalvor@gmail.com";
        homeDirectory = "/home/henhal";
        term = "kitty";
        browser = "vivaldi";
        stateVersion = "25.05";
        stylixTheme = {
          scheme = "gruvbox-dark-hard";
          wallpaper = "starry-sky.png";
        };
      };
      henhal-dev = {
        username = "henhal-dev";
        name = "Henrik";
        email = "henhalvor@gmail.com";
        homeDirectory = "/home/henhal-dev";
        stateVersion = "25.05";
      };
    };

    # System builder
    mkSystem = import ./lib/mk-nixos-system.nix inputs;
  in {
    nixosConfigurations = {
      workstation = mkSystem {
        hostConfig = hosts.workstation;
        userSettings = users.henhal;
      };

      lenovo-yoga-pro-7 = mkSystem {
        hostConfig = hosts.lenovo-yoga-pro-7;
        userSettings = users.henhal;
      };

      hp-server = mkSystem {
        hostConfig = hosts.hp-server;
        userSettings = users.henhal-dev;
        extraModules = [ /* vscode-server, etc */ ];
      };
    };
  };
}
```

**Acceptance Criteria:**
- [ ] `hosts/` contains pure data files (no imports)
- [ ] `lib/desktop.nix` resolves null → defaults correctly
- [ ] `flake.nix` is clean and minimal
- [ ] `desktop.bar` etc. are pre-resolved in specialArgs

---

### Phase 2: Shared Theme + NixOS Stylix

**Objective:** Single source of truth for theming.

#### 2.1 Create `nixos/modules/theme/stylix.nix`

```nix
# nixos/modules/theme/stylix.nix
{ config, pkgs, lib, userSettings, ... }:
let
  theme = import ../../../lib/theme.nix { inherit pkgs userSettings; };
in {
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    base16Scheme = theme.base16Scheme;
    image = theme.image;
    cursor = theme.cursor;
    fonts = theme.fonts;
  };
}
```

#### 2.2 Update `home/modules/themes/stylix/default.nix`

```nix
# home/modules/themes/stylix/default.nix
{ config, pkgs, lib, userSettings, ... }:
let
  theme = import ../../../../lib/theme.nix { inherit pkgs userSettings; };
in {
  stylix = {
    enable = true;
    autoEnable = true;
    polarity = "dark";
    base16Scheme = theme.base16Scheme;
    image = theme.image;
    cursor = theme.cursor;
    fonts = theme.fonts;
    targets.neovim.enable = false;
  };
}
```

**Acceptance Criteria:**
- [ ] `config.stylix.*` exists on NixOS side
- [ ] Changing `userSettings.stylixTheme` affects both NixOS and HM

---

### Phase 3: NixOS Desktop Dispatcher

**Objective:** Replace WM conditional imports with lookup-table dispatcher.

#### 3.1 Create `nixos/modules/desktop/default.nix`

Uses lookup tables instead of if/else chains:

```nix
# nixos/modules/desktop/default.nix
{ config, lib, pkgs, desktop, userSettings, ... }:
let
  # Lookup tables - add new sessions/DMs here
  sessionModules = {
    hyprland = ./sessions/hyprland.nix;
    sway = ./sessions/sway.nix;
    gnome = ./sessions/gnome.nix;
  };

  dmModules = {
    sddm = ./display-managers/sddm.nix;
    gdm = ./display-managers/gdm.nix;
  };

  session = desktop.session;
  dm = desktop.dm;
  enabled = session != "none";
in {
  imports = lib.optionals enabled ([
    ./common.nix
  ] ++ lib.optional (sessionModules ? ${session}) sessionModules.${session}
    ++ lib.optional (dmModules ? ${dm}) dmModules.${dm}
  );
}
```

#### 3.2 Create `nixos/modules/desktop/common.nix`

```nix
# nixos/modules/desktop/common.nix
{ config, lib, pkgs, ... }:
{
  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  programs.dconf.enable = true;

  fonts.packages = with pkgs; [ noto-fonts noto-fonts-emoji ];
}
```

#### 3.3 Create session modules

```nix
# nixos/modules/desktop/sessions/hyprland.nix
{ config, lib, pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  security.pam.services.hyprlock = {};
}
```

```nix
# nixos/modules/desktop/sessions/sway.nix
{ config, lib, pkgs, ... }:
{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
  security.pam.services.swaylock = {};
}
```

```nix
# nixos/modules/desktop/sessions/gnome.nix
{ config, lib, pkgs, ... }:
{
  services.xserver = {
    enable = true;
    desktopManager.gnome.enable = true;
  };
  environment.gnome.excludePackages = with pkgs; [ gnome-tour epiphany ];
}
```

#### 3.4 Create display manager modules

```nix
# nixos/modules/desktop/display-managers/sddm.nix
{ config, lib, pkgs, userSettings, ... }:
{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "where_is_my_sddm_theme";
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = userSettings.username;
  };

  environment.systemPackages = [
    (pkgs.where-is-my-sddm-theme.override {
      themeConfig.General = {
        background = "${config.stylix.image}";
        backgroundMode = "fill";
      };
    })
  ];
}
```

```nix
# nixos/modules/desktop/display-managers/gdm.nix
{ config, lib, pkgs, ... }:
{
  services.xserver.displayManager.gdm = {
    enable = true;
    wayland = true;
  };
}
```

#### 3.5 Update `systems/workstation/configuration.nix`

```nix
# systems/workstation/configuration.nix
{ config, pkgs, desktop, hostConfig, userSettings, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../nixos/default.nix
    # No more WM conditionals! Desktop module handles it.
  ];

  # Hardware based on hostConfig
  services.xserver.videoDrivers =
    lib.mkIf (hostConfig.hardware.gpu or "" == "nvidia") [ "nvidia" ];

  hardware.logitech.wireless.enable = hostConfig.hardware.logitech or false;

  # ... rest of hardware-specific config
}
```

**Acceptance Criteria:**
- [ ] No if/else chains in dispatcher (uses lookup tables)
- [ ] Adding new session = add to lookup table + create module
- [ ] `desktop.session` and `desktop.dm` come pre-resolved from flake
- [ ] All hosts build successfully

---

### Phase 4: Home Manager Desktop Dispatcher

**Objective:** Full component selection with lookup tables, using pre-resolved `desktop` from specialArgs.

#### 4.1 Create `home/modules/desktop/default.nix`

```nix
# home/modules/desktop/default.nix
{ config, lib, pkgs, desktop, hostConfig, userSettings, ... }:
let
  # Lookup tables - add new components here
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

  enabled = desktop.session != "none";
in {
  imports = lib.optionals enabled ([
    ./common.nix
    ./launchers/rofi.nix
  ] ++ lib.optional (sessionModules ? ${desktop.session}) sessionModules.${desktop.session}
    ++ lib.optional (barModules ? ${desktop.bar}) barModules.${desktop.bar}
    ++ lib.optional (lockModules ? ${desktop.lock}) lockModules.${desktop.lock}
    ++ lib.optional (idleModules ? ${desktop.idle}) idleModules.${desktop.idle}
  );
}
```

#### 4.2 Create `home/modules/desktop/common.nix`

```nix
# home/modules/desktop/common.nix
{ config, lib, pkgs, desktop, userSettings, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    libnotify
    playerctl
    brightnessctl
    pamixer
  ];

  xdg.enable = true;

  home.sessionVariables = {
    TERMINAL = userSettings.term;
    BROWSER = userSettings.browser;
  };
}
```

#### 4.3 Create bar modules

```nix
# home/modules/desktop/bars/waybar.nix
{ config, lib, pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "hyprland/workspaces" "sway/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "pulseaudio" "battery" "tray" ];

      clock.format = "{:%H:%M}";
      battery = {
        format = "{icon} {capacity}%";
        format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      };
      pulseaudio = {
        format = "{icon} {volume}%";
        format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
      };
    };

    # Stylix colors (no more hardcoded Catppuccin)
    style = ''
      * {
        font-family: "${config.stylix.fonts.monospace.name}";
        font-size: ${toString config.stylix.fonts.sizes.desktop}pt;
      }
      window#waybar { background-color: alpha(@base00, 0.9); color: @base05; }
      #workspaces button { color: @base04; }
      #workspaces button.active { color: @base0D; background-color: @base02; }
      #clock, #battery, #pulseaudio { padding: 0 10px; color: @base05; }
    '';
  };
}
```

```nix
# home/modules/desktop/bars/hyprpanel.nix
{ config, lib, pkgs, desktop, userSettings, hostConfig, ... }:
let
  themeMap = {
    "catppuccin-mocha" = "catppuccin_mocha";
    "catppuccin-macchiato" = "catppuccin_macchiato";
    "gruvbox-dark-hard" = "gruvbox";
    "nord" = "nord";
    "dracula" = "dracula";
    "rose-pine-moon" = "rose_pine_moon";
  };

  theme = themeMap.${userSettings.stylixTheme.scheme} or "catppuccin_mocha";
  hostSettings = hostConfig.desktop.hyprpanel or {};

  finalConfig = lib.recursiveUpdate { theme.name = theme; } hostSettings;
in {
  home.packages = [ pkgs.hyprpanel ];
  xdg.configFile."hyprpanel/config.json".text = builtins.toJSON finalConfig;
}
```

#### 4.4 Create lock modules

```nix
# home/modules/desktop/lock/hyprlock.nix
{ config, lib, pkgs, ... }:
{
  programs.hyprlock = {
    enable = true;
    settings = {
      background = [{
        path = "${config.stylix.image}";
        blur_passes = 2;
        blur_size = 4;
      }];
      input-field = [{
        size = "250, 50";
        outline_thickness = 2;
        fade_on_empty = true;
        placeholder_text = "Password...";
      }];
    };
  };
}
```

```nix
# home/modules/desktop/lock/swaylock.nix
{ config, lib, pkgs, ... }:
let colors = config.lib.stylix.colors; in
{
  programs.swaylock = {
    enable = true;
    settings = {
      image = "${config.stylix.image}";
      scaling = "fill";
      indicator-radius = 100;
      show-failed-attempts = true;
      color = colors.base00;
      inside-color = colors.base01;
      ring-color = colors.base0D;
      key-hl-color = colors.base0B;
    };
  };
}
```

#### 4.5 Create idle modules

```nix
# home/modules/desktop/idle/hypridle.nix
{ config, lib, pkgs, desktop, ... }:
let
  lockBin = {
    hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
    swaylock = "${pkgs.swaylock}/bin/swaylock";
    loginctl = "loginctl lock-session";
  }.${desktop.lock} or "loginctl lock-session";
in {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof ${desktop.lock} || ${lockBin}";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 300; on-timeout = lockBin; }
        { timeout = 600; on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
      ];
    };
  };
}
```

```nix
# home/modules/desktop/idle/swayidle.nix
{ config, lib, pkgs, desktop, ... }:
let
  lockBin = {
    swaylock = "${pkgs.swaylock}/bin/swaylock -f";
    hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
    loginctl = "loginctl lock-session";
  }.${desktop.lock} or "loginctl lock-session";
in {
  services.swayidle = {
    enable = true;
    timeouts = [
      { timeout = 300; command = lockBin; }
      { timeout = 600; command = "swaymsg 'output * dpms off'"; resumeCommand = "swaymsg 'output * dpms on'"; }
    ];
    events = [
      { event = "before-sleep"; command = lockBin; }
    ];
  };
}
```

#### 4.6 Create rofi module

```nix
# home/modules/desktop/launchers/rofi.nix
{ config, lib, pkgs, desktop, ... }:
let
  lockBin = {
    hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
    swaylock = "${pkgs.swaylock}/bin/swaylock";
    loginctl = "loginctl lock-session";
    none = "true";
  }.${desktop.lock} or "true";

  colors = config.lib.stylix.colors;
in {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    theme = {
      "*" = {
        background-color = lib.mkForce "#${colors.base00}";
        text-color = lib.mkForce "#${colors.base05}";
        border-color = lib.mkForce "#${colors.base0D}";
      };
    };
  };

  home.file.".config/rofi/scripts/powermenu.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      chosen=$(printf "Lock\nLogout\nSuspend\nReboot\nShutdown" | rofi -dmenu -p "Power")
      case "$chosen" in
        Lock) ${lockBin} ;;
        Logout) loginctl terminate-user $USER ;;
        Suspend) systemctl suspend ;;
        Reboot) systemctl reboot ;;
        Shutdown) systemctl poweroff ;;
      esac
    '';
  };
}
```

#### 4.7 Update `users/henhal/home.nix`

```nix
# users/henhal/home.nix
{ config, pkgs, desktop, userSettings, inputs, ... }:
{
  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";
  home.stateVersion = userSettings.stateVersion;

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

  imports = [
    inputs.stylix.homeModules.stylix
    ../../home/modules/themes/stylix/default.nix
    ../../home/modules/desktop/default.nix    # Handles all desktop components

    # Applications (unchanged)
    ../../home/modules/applications/zsh.nix
    ../../home/modules/applications/${userSettings.term}.nix
    ../../home/modules/applications/${userSettings.browser}.nix
    # ... rest of imports
  ];

  # No more my.desktop options! Everything comes from `desktop` in specialArgs.
}
```

**Acceptance Criteria:**
- [ ] Dispatcher uses lookup tables (no if/else chains)
- [ ] `desktop.*` values come pre-resolved from specialArgs
- [ ] Rofi uses correct lock command per host
- [ ] Waybar uses Stylix colors
- [ ] workstation: hyprland + hyprpanel + hyprlock + hypridle
- [ ] lenovo-yoga-pro-7: sway + waybar + swaylock + swayidle

---

### Phase 5: Session Modules Using Host Data

**Objective:** Session modules read from `hostConfig.desktop` (pure data from hosts/).

#### 5.1 Create session modules that consume host data

```nix
# home/modules/desktop/sessions/hyprland.nix
{ config, lib, pkgs, desktop, hostConfig, userSettings, ... }:
let
  d = hostConfig.desktop;
  monitors = d.monitors or [ ",preferred,auto,1" ];
  workspaceRules = d.workspaceRules or [];
  extraConfig = d.extraConfig or "";
in {
  wayland.windowManager.hyprland = {
    enable = true;

    settings = {
      monitor = monitors;
      workspace = workspaceRules;

      "$terminal" = userSettings.term;
      "$browser" = userSettings.browser;

      exec-once = [
        "$browser"
      ];

      bind = [
        "SUPER, Return, exec, $terminal"
        "SUPER, B, exec, $browser"
        "SUPER, Q, killactive"
        "SUPER, L, exec, ${desktop.lock}"
        "SUPER, Space, exec, rofi -show drun"
        # ... more binds
      ];

      input.kb_layout = "no";
    };

    extraConfig = extraConfig;
  };

  services.kanshi = {
    enable = true;
    systemdTarget = "hyprland-session.target";
  };
}
```

```nix
# home/modules/desktop/sessions/sway.nix
{ config, lib, pkgs, desktop, hostConfig, userSettings, ... }:
let
  d = hostConfig.desktop;
  outputs = d.outputs or {};
  extraConfig = d.extraConfig or "";
in {
  wayland.windowManager.sway = {
    enable = true;

    config = {
      terminal = userSettings.term;
      output = outputs;

      input."type:keyboard".xkb_layout = "no";

      keybindings = let mod = "Mod4"; in {
        "${mod}+Return" = "exec ${userSettings.term}";
        "${mod}+b" = "exec ${userSettings.browser}";
        "${mod}+q" = "kill";
        "${mod}+l" = "exec ${desktop.lock}";
        "${mod}+Space" = "exec rofi -show drun";
      };

      startup = [
        { command = userSettings.browser; }
      ];
    };

    extraConfig = extraConfig;
  };

  services.kanshi = {
    enable = true;
    systemdTarget = "sway-session.target";
  };
}
```

```nix
# home/modules/desktop/sessions/gnome.nix
{ config, lib, pkgs, ... }:
{
  # Minimal GNOME HM config - most handled by NixOS
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
```

#### 5.2 Host data structure reference

All desktop-specific data lives in `hosts/*.nix`:

```nix
# hosts/workstation.nix
{
  hostname = "workstation";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";

    # Hyprland-specific
    monitors = [
      "DP-1,3440x1440@144,0x0,1"
      "DP-2,2560x1440@144,3440x0,1"
    ];
    workspaceRules = [
      "1, monitor:DP-1, default:true"
      "4, monitor:DP-2, default:true"
    ];

    # Hyprpanel overrides (optional)
    hyprpanel = {
      bar.position = "top";
    };
  };

  hardware = { gpu = "nvidia"; };
}
```

```nix
# hosts/lenovo-yoga-pro-7.nix
{
  hostname = "yoga-pro-7";

  desktop = {
    session = "sway";
    bar = "waybar";

    # Sway-specific
    outputs = {
      "eDP-1" = { resolution = "2880x1800@120Hz"; scale = 1.5; };
    };
    extraConfig = ''
      input type:touchpad {
        tap enabled
        natural_scroll enabled
      }
    '';
  };

  hardware = { gpu = "amd"; };
}
```

**Acceptance Criteria:**
- [ ] Session modules contain no per-host config tables
- [ ] All monitor/workspace config comes from `hostConfig.desktop`
- [ ] Adding new host = create `hosts/<name>.nix`, no module edits
- [ ] Both workstation and laptop build and work

---

### Phase 6: Full Theming Consistency

**Objective:** Stylix colors flow into all components.

#### 6.1 SDDM theme from Stylix

```nix
# nixos/modules/desktop/display-managers/sddm.nix
{ config, lib, pkgs, userSettings, ... }:
let
  colors = config.lib.stylix.colors;
in {
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "where_is_my_sddm_theme";
  };

  environment.systemPackages = [
    (pkgs.where-is-my-sddm-theme.override {
      themeConfig.General = {
        background = "${config.stylix.image}";
        backgroundMode = "fill";
        basicTextColor = "#${colors.base05}";
        passwordInputBackground = "#${colors.base01}";
        passwordInputCursorColor = "#${colors.base0D}";
      };
    })
  ];
}
```

#### 6.2 Mako notifications with Stylix

```nix
# home/modules/desktop/common.nix (add mako)
{ config, ... }:
let colors = config.lib.stylix.colors; in
{
  services.mako = {
    enable = true;
    backgroundColor = "#${colors.base00}";
    textColor = "#${colors.base05}";
    borderColor = "#${colors.base0D}";
    borderRadius = 8;
    borderSize = 2;
    font = "${config.stylix.fonts.sansSerif.name} ${toString config.stylix.fonts.sizes.popups}";
  };
}
```

#### 6.3 Hyprpanel theme generation (optional enhancement)

Generate theme from Stylix colors instead of scheme-name mapping:

```nix
# home/modules/desktop/bars/hyprpanel.nix (enhanced)
let
  colors = config.lib.stylix.colors;
  generatedTheme = {
    theme.bar = {
      background = "#${colors.base00}";
      foreground = "#${colors.base05}";
      accent = "#${colors.base0D}";
    };
  };
in {
  xdg.configFile."hyprpanel/config.json".text =
    builtins.toJSON (lib.recursiveUpdate generatedTheme hostSettings);
}
```

**Acceptance Criteria:**
- [ ] Changing `userSettings.stylixTheme` updates all components:
  - SDDM, Rofi, Waybar, Mako, Hyprlock/Swaylock, Hyprpanel

---

### Phase 7: Cleanup + Documentation

**Objective:** Remove deprecated paths, add docs.

#### 7.1 Delete old modules

```bash
rm -rf nixos/modules/window-manager/
rm -rf home/modules/window-manager/
```

#### 7.2 Verify kanshi is HM-only

Kanshi configured in Home Manager session modules, not NixOS.

#### 7.3 Add documentation

Create `docs/desktop-switching.md`:

```markdown
# Desktop Session Switching

## Quick Start

1. Create host file in `hosts/`:

\`\`\`nix
# hosts/my-machine.nix
{
  hostname = "my-machine";

  desktop = {
    session = "hyprland";    # or "sway", "gnome", "none"
    bar = "hyprpanel";       # or "waybar", null (auto)
    lock = null;             # null = use session default
    idle = null;

    monitors = [ "DP-1,1920x1080@60,0x0,1" ];
  };

  hardware = {
    gpu = "nvidia";          # or "amd", "intel"
  };
}
\`\`\`

2. Add to `flake.nix`:

\`\`\`nix
my-machine = mkSystem {
  hostConfig = hosts.my-machine;
  userSettings = users.myuser;
};
\`\`\`

## Per-Session Defaults

| Session | Bar | Lock | Idle | DM |
|---------|-----|------|------|-----|
| hyprland | hyprpanel | hyprlock | hypridle | sddm |
| sway | waybar | swaylock | swayidle | sddm |
| gnome | none | loginctl | none | gdm |

## Theming

All components use Stylix. Change in user settings:

\`\`\`nix
stylixTheme = {
  scheme = "gruvbox-dark-hard";
  wallpaper = "starry-sky.png";
};
\`\`\`
```

**Acceptance Criteria:**
- [ ] No WM-selection if/else blocks remain
- [ ] No hardcoded usernames
- [ ] `hosts/` contains all host-specific data
- [ ] Clear documentation exists
- [ ] All hosts build and boot correctly

---

## Summary: Data Flow

```
hosts/workstation.nix (pure data)
        │
        ▼
flake.nix imports host, passes to mkSystem
        │
        ▼
lib/mk-nixos-system.nix
  ├── Resolves desktop defaults (lib/desktop.nix)
  ├── Passes `desktop` and `hostConfig` via specialArgs
        │
        ▼
┌───────────────────────────────────────┐
│ NixOS modules                         │
│  └── desktop/default.nix              │
│       ├── Reads desktop.session       │
│       ├── Lookup table → session mod  │
│       └── Lookup table → DM module    │
└───────────────────────────────────────┘
        │
        ▼
┌───────────────────────────────────────┐
│ Home Manager modules                  │
│  └── desktop/default.nix              │
│       ├── Reads desktop.{session,bar} │
│       ├── Lookup table → session mod  │
│       ├── Lookup table → bar module   │
│       ├── Lookup table → lock module  │
│       └── Lookup table → idle module  │
│                                       │
│  Session modules read hostConfig for: │
│    - monitors, workspaceRules         │
│    - outputs, extraConfig             │
└───────────────────────────────────────┘
```

---

## Implementation Notes

### Key Gotchas

1. **NixOS and HM Stylix are separate** - Share config via `lib/theme.nix`

2. **Session targets matter** - Kanshi/waybar systemd use:
   - Hyprland: `hyprland-session.target`
   - Sway: `sway-session.target`

3. **Lock command** - Comes from `desktop.lock` (pre-resolved), not guessed

4. **Hyprpanel JSON merge** - Use `lib.recursiveUpdate` to merge theme + host config

5. **Autologin user** - Always `userSettings.username`, never hardcode

6. **Host data is pure** - No `lib`, `pkgs`, or imports in `hosts/*.nix`

### Testing Each Phase

```bash
# Build without switching
nixos-rebuild build --flake .#workstation
nixos-rebuild build --flake .#lenovo-yoga-pro-7

# Test in VM (optional)
nixos-rebuild build-vm --flake .#workstation

# Switch
sudo nixos-rebuild switch --flake .#workstation
```

### Rollback

```bash
sudo nixos-rebuild switch --rollback
```

---

## Files Changed Summary

### New Files
```
hosts/
├── workstation.nix
├── lenovo-yoga-pro-7.nix
└── hp-server.nix

lib/
├── desktop.nix
├── theme.nix
└── mk-nixos-system.nix

nixos/modules/desktop/
├── default.nix
├── common.nix
├── sessions/{hyprland,sway,gnome}.nix
└── display-managers/{sddm,gdm}.nix

nixos/modules/theme/
└── stylix.nix

home/modules/desktop/
├── default.nix
├── common.nix
├── sessions/{hyprland,sway,gnome}.nix
├── bars/{waybar,hyprpanel}.nix
├── lock/{hyprlock,swaylock}.nix
├── idle/{hypridle,swayidle}.nix
└── launchers/rofi.nix
```

### Modified Files
```
flake.nix                           # Simplified, uses mkSystem + hosts
systems/*/configuration.nix         # Remove WM conditionals, use hostConfig
users/henhal/home.nix               # Remove WM conditionals
home/modules/themes/stylix/         # Use lib/theme.nix
```

### Deleted Files (Phase 7)
```
nixos/modules/window-manager/       # Entire directory
home/modules/window-manager/        # Entire directory
```
