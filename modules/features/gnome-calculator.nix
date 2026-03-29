# GNOME Calculator
# Source: home/modules/applications/gnome-calculator.nix
{ self, ... }: {
  flake.nixosModules.gnomeCalculator = { ... }: {
    home-manager.sharedModules = [ self.homeModules.gnomeCalculator ];
  };
  flake.homeModules.gnomeCalculator = { pkgs, ... }: {
    home.packages = with pkgs; [ gnome-calculator ];
  };
}
