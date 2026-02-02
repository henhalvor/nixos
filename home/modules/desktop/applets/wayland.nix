{ config, lib, pkgs, ... }:
{
  # Wayland system tray applets
  services.blueman-applet.enable = true;
  services.network-manager-applet.enable = true;

  home.packages = with pkgs; [
    blueman
    networkmanagerapplet
  ];
}
