

{ config, pkgs, userSettings, systemSettings, ... }:
{
  # enable gnome
  services.xserver.desktopManager.gnome.enable = true;

  }
