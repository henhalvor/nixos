# Firefox — browser
# Source: home/modules/applications/firefox.nix
# Template B2: HM-only
{ self, ... }: {
  flake.nixosModules.firefox = { ... }: {
    home-manager.sharedModules = [ self.homeModules.firefox ];
  };

  flake.homeModules.firefox = { ... }: {
    programs.firefox.enable = true;
  };
}
