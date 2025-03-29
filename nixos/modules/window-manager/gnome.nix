

{ config, pkgs, userSettings, ... }: {
  # enable gnome
  services.xserver.desktopManager.gnome.enable = true;

}
