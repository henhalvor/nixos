# Bottles — Wine manager for Windows apps
# Source: home/modules/environment/bottles.nix
{ self, ... }: {
  flake.nixosModules.bottles = { ... }: {
    home-manager.sharedModules = [ self.homeModules.bottles ];
  };

  flake.homeModules.bottles = { pkgs, ... }: {
    home.packages = with pkgs; [
      bottles
      wineWowPackages.stable
      winetricks
      cabextract
    ];
  };
}
