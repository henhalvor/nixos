{ config, lib, pkgs, ... }:
{
  # Minimal GNOME HM config - most handled by NixOS
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
