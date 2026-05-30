# Obsidian — note-taking app (from unstable)
# Source: home/modules/applications/obsidian.nix
# Template B2: HM-only
{ self, ... }:
{
  flake.nixosModules.obsidian =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.obsidian ];
    };

  flake.homeModules.obsidian =
    { config, pkgs-unstable, ... }:
    {
      home.packages = [ pkgs-unstable.obsidian ];

      xdg.configFile."obsidian/obsidian.json".text = builtins.toJSON {
        updateDisabled = true;
        vaults."5b70a213f150f01f0776fa9481ef2ddf" = {
          path = "${config.home.homeDirectory}/Vault";
          open = true;
        };
      };
    };
}
