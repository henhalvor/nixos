# Brave — browser
# Source: home/modules/applications/brave.nix
# Template B2: HM-only
{ self, ... }: {
  flake.nixosModules.brave = { ... }: {
    home-manager.sharedModules = [ self.homeModules.brave ];
  };

  flake.homeModules.brave = { pkgs, ... }: {
    home.packages = with pkgs; [ brave ];
  };
}
