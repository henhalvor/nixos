# Spotify — music streaming
# Source: home/modules/applications/spotify.nix
{ self, ... }: {
  flake.nixosModules.spotify = { ... }: {
    home-manager.sharedModules = [ self.homeModules.spotify ];
  };
  flake.homeModules.spotify = { pkgs, ... }: {
    home.packages = with pkgs; [ spotify ];
  };
}
