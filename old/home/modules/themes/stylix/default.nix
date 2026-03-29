{ config, pkgs, lib, userSettings, ... }:
let
  theme = import ../../../../lib/theme.nix { inherit pkgs userSettings; };
in {
  # Stylix Home Manager targets
  # Note: The main stylix configuration is done at the NixOS level
  # This just enables/disables specific targets for Home Manager
  stylix.targets.neovim.enable = false;
}
