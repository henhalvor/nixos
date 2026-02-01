{ config, lib, pkgs, ... }:
{
  # Import existing hyprpanel configuration
  imports = [ ../../window-manager/hyprpanel ];
}
