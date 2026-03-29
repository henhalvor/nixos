# Qalculate — calculator (currently unused)
# Source: home/modules/applications/qalculate.nix
{ self, ... }: {
  flake.nixosModules.qalculate = { ... }: {
    home-manager.sharedModules = [ self.homeModules.qalculate ];
  };
  flake.homeModules.qalculate = { pkgs, ... }: {
    home.packages = with pkgs; [ qalculate-gtk ];
  };
}
