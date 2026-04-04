# Swaylock — screen locker for Wayland
# Source: home/modules/desktop/lock/swaylock.nix
# Template B2: HM-only with Stylix colors
{self, ...}: {
  flake.nixosModules.swaylock = {...}: {
    home-manager.sharedModules = [self.homeModules.swaylock];
  };

  flake.homeModules.swaylock = {config, lib, ...}: let
    colors = config.lib.stylix.colors;
  in {
    programs.swaylock = {
      enable = true;
      settings = {
        image = lib.mkDefault "${config.stylix.image}";
        scaling = lib.mkDefault "fill";
        indicator-radius = lib.mkDefault 100;
        show-failed-attempts = lib.mkDefault true;
        color = lib.mkDefault colors.base00;
        inside-color = lib.mkDefault colors.base01;
        ring-color = lib.mkDefault colors.base0D;
        key-hl-color = lib.mkDefault colors.base0B;
      };
    };
  };
}
