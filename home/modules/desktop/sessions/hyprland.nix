{ config, lib, pkgs, ... }:
{
  # Import existing hyprland configuration
  imports = [ ../../window-manager/hyprland.nix ];
}
