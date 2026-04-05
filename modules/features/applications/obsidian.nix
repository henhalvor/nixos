# Obsidian — note-taking app (from unstable)
# Source: home/modules/applications/obsidian.nix
# Template B2: HM-only
{self, ...}: {
  flake.nixosModules.obsidian = {...}: {
    home-manager.sharedModules = [self.homeModules.obsidian];
  };

  flake.homeModules.obsidian = {pkgs-unstable, ...}: {
    programs.obsidian = {
      enable = true;
      package = pkgs-unstable.obsidian;
      vaults.default.target = "Vault";
    };
  };
}
