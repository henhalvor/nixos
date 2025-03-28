

{ config, pkgs, userSettings, systemSettings, ... }:
{
  imports = [
    ./wayland-session-variables.nix
  ];

  # Enable Wayland compositor - Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

}
