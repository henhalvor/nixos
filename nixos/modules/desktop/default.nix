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
