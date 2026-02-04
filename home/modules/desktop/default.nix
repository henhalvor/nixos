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
    loginctl = ./lock/loginctl.nix;
    none = ./lock/none.nix;
  };

  idleModules = {
    hypridle = ./idle/hypridle.nix;
    swayidle = ./idle/swayidle.nix;
    none = ./idle/none.nix;
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

  notificationModules = {
    mako = ./notifications/mako.nix;
    dunst = ./notifications/dunst.nix;
    none = ./notifications/none.nix;
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
  
  # Helper for safe module imports - handle null/missing options
  importModule = modules: key:
    lib.optional (key != null && builtins.hasAttr key modules) modules.${key};
in {
  imports = lib.optionals enabled ([
    ./common.nix
  ] 
  ++ importModule sessionModules desktop.session
  ++ importModule barModules desktop.bar
  ++ importModule lockModules desktop.lock
  ++ importModule idleModules desktop.idle
  ++ importModule clipboardModules desktop.clipboard
  ++ importModule screenshotModules desktop.screenshotTool
  ++ importModule notificationModules desktop.notifications
  ++ importModule trayAppletModules desktop.trayApplets
  ++ importModule nightLightModules desktop.nightLight
  );

  # Validation
  config = lib.mkIf enabled {
    assertions = [
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
      
      # Idle validation
      {
        assertion = desktop.idle == null || builtins.hasAttr desktop.idle idleModules;
        message = "Unknown desktop.idle: '${desktop.idle}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames idleModules)}";
      }
      
      # Lock validation
      {
        assertion = desktop.lock == null || builtins.hasAttr desktop.lock lockModules;
        message = "Unknown desktop.lock: '${desktop.lock}'. Valid: ${lib.concatStringsSep ", " (builtins.attrNames lockModules)}";
      }
      
      # CRITICAL: Prevent idle without lock
      {
        assertion = !(desktop.idle != "none" && desktop.lock == "none");
        message = ''
          Incompatible configuration: desktop.idle = "${desktop.idle}" requires a lock screen.
          
          Idle daemons need a lock screen to function properly.
          
          Fix by choosing one:
            1. Disable idle daemon: desktop.idle = "none"
            2. Enable a lock screen: desktop.lock = "hyprlock" (or swaylock/loginctl)
        '';
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
               desktop.notifications = "none"  (or remove it - this is the default)
            
            2. Use a different bar with mako:
               desktop.bar = "waybar"
               desktop.notifications = "mako"
        '';
      }
    ];
  };
}
