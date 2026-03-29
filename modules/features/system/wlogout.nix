# Wlogout — logout menu
# Source: home/modules/desktop/logout/wlogout.nix
# Template B2: HM-only
{self, ...}: {
  flake.nixosModules.wlogout = {...}: {
    home-manager.sharedModules = [self.homeModules.wlogout];
  };

  flake.homeModules.wlogout = {...}: {
    programs.wlogout.enable = true;
  };
}
