# GIMP — image editor
# Source: home/modules/applications/gimp.nix
{ self, ... }: {
  flake.nixosModules.gimp = { ... }: {
    home-manager.sharedModules = [ self.homeModules.gimp ];
  };
  flake.homeModules.gimp = { pkgs, ... }: {
    home.packages = with pkgs; [ gimp ];
  };
}
