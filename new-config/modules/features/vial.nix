# Vial — keyboard configurator
# Source: home/modules/applications/vial.nix
{ self, ... }: {
  flake.nixosModules.vial = { ... }: {
    home-manager.sharedModules = [ self.homeModules.vial ];
  };
  flake.homeModules.vial = { pkgs, ... }: {
    home.packages = with pkgs; [ vial ];
  };
}
