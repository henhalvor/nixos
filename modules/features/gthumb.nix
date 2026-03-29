# gThumb — image viewer
# Source: home/modules/applications/gthumb.nix
{ self, ... }: {
  flake.nixosModules.gthumb = { ... }: {
    home-manager.sharedModules = [ self.homeModules.gthumb ];
  };
  flake.homeModules.gthumb = { pkgs, ... }: {
    home.packages = with pkgs; [ gthumb ];
  };
}
