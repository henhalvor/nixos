# Mako — notification daemon
# Source: home/modules/desktop/notifications/mako.nix
# Template B2: HM-only (Stylix handles theming)
{self, ...}: {
  flake.nixosModules.mako = {...}: {
    home-manager.sharedModules = [self.homeModules.mako];
  };

  flake.homeModules.mako = {pkgs, ...}: {
    services.mako = {
      enable = true;
      settings = {
        default-timeout = 5000;
        anchor = "top-right";
        max-visible = 5;
      };
    };

    home.packages = with pkgs; [libnotify mako];
  };
}
