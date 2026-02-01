

{ config, pkgs, userSettings, ... }: {
  imports = [ ./wayland-session-variables.nix ];

  # Enable Wayland compositor - Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

}
