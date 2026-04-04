# Direnv — per-directory environment with nix-direnv
# Source: home/modules/environment/direnv.nix
{ self, ... }: {
  flake.nixosModules.direnv = { ... }: {
    home-manager.sharedModules = [ self.homeModules.direnv ];
  };

  flake.homeModules.direnv = { ... }: {
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
