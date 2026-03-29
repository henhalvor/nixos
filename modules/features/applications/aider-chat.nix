# Aider Chat — AI pair programming (from unstable, commented-out originally)
# Source: home/modules/applications/aider-chat.nix
{ self, ... }: {
  flake.nixosModules.aiderChat = { ... }: {
    home-manager.sharedModules = [ self.homeModules.aiderChat ];
  };
  flake.homeModules.aiderChat = { pkgs-unstable, ... }: {
    home.packages = [ pkgs-unstable.aider-chat ];
  };
}
