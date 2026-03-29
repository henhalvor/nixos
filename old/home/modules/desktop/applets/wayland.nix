{
  config,
  lib,
  pkgs,
  ...
}: {
  # Wayland system tray applets
  services.blueman-applet.enable = false;
  services.network-manager-applet.enable = true;

  home.packages = with pkgs; [
    # blueman
    networkmanagerapplet
  ];
}
