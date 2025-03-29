

{ config, pkgs, userSettings, ... }: {
  imports = [ ./wayland-session-variables.nix ];

  programs.sway = {
    enable = true;
    xwayland.enable = true;
  };

  # Nixos wiki says this has to be enabled to use sway: https://nixos.wiki/wiki/Sway
  security.polkit.enable = true;

  # Allow sway to use the video group for brightness and volume control
  users.users.${userSettings.username}.extraGroups = [ "video" ];
  programs.light.enable = true;

  # kanshi systemd service for monitor hot swapping
  systemd.user.services.kanshi = {
    description = "kanshi daemon";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kanshi}/bin/kanshi -c ~/.config/kanshi/config";
    };
  };

}
