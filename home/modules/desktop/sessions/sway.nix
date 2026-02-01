{ config, lib, pkgs, ... }:
{
  # Import existing sway configuration
  imports = [ ../../window-manager/sway.nix ];
}
