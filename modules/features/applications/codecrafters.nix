# codecrafters — CLI
# Source: home/modules/applications/codecrafters.nix
# Template B2: HM-only
{ self, ... }:
{
  flake.nixosModules.codecrafters-cli =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.codecrafters-cli ];
    };

  flake.homeModules.codecrafters-cli =
    { pkgs-unstable, ... }:
    {
      home.packages = [ pkgs-unstable.codecrafters-cli ];
    };
}
