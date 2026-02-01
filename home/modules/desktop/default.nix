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
    # Temporarily commented - these are in old WM modules that we're importing
    # ./launchers/rofi.nix
  ] ++ lib.optional (sessionModules ? ${desktop.session}) sessionModules.${desktop.session}
    ++ lib.optional (barModules ? ${desktop.bar}) barModules.${desktop.bar}
    # ++ lib.optional (lockModules ? ${desktop.lock}) lockModules.${desktop.lock}
    # ++ lib.optional (idleModules ? ${desktop.idle}) idleModules.${desktop.idle}
  );
}
