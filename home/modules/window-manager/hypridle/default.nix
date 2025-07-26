{ config, lib, pkgs, systemName, ... }:

let
  # Import both configs
  laptopConfig = import ./laptop.nix { inherit config lib pkgs; };
  desktopConfig = import ./desktop.nix { inherit config lib pkgs; };

  # Choose config based on systemName
  selectedConfig =
    if systemName == "workstation" then desktopConfig else laptopConfig;
in selectedConfig

