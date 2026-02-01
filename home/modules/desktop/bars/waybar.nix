{ config, lib, pkgs, ... }:
{
  # Import existing waybar configuration
  imports = [ ../../window-manager/waybar ];
}
