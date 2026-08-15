{ ... }:
{
  flake.nixosModules.garbageCollection =
    { ... }:
    {
      nix.gc = {
        automatic = true;
        dates = "weekly"; # Options include "daily", "weekly", or specific times like "02:30"
        options = "--delete-older-than 30d";
      };

      # Optional: Automatically optimize the Nix store on each run to hardlink identical files
      nix.settings.auto-optimise-store = true;

    };
}
