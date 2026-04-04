# Amazon Q CLI — AI assistant
# Source: home/modules/applications/amazon-q.nix
{ self, ... }: {
  flake.nixosModules.amazonQ = { ... }: {
    home-manager.sharedModules = [ self.homeModules.amazonQ ];
  };
  flake.homeModules.amazonQ = { pkgs, ... }: {
    home.packages = with pkgs; [ amazon-q-cli ];
  };
}
