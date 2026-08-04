# OpenCloud Desktop on the personal NixOS machines.  The application owns its
# account/session configuration; Home Manager only installs it and creates the
# deliberately narrow local sync root.
{ self, ... }:
{
  flake.nixosModules.opencloudDesktop =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.opencloudDesktop ];
    };

  flake.homeModules.opencloudDesktop =
    { lib, pkgs, ... }:
    {
      home.packages = [ pkgs.opencloud-desktop ];

      home.activation.createOpencloudSyncRoot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p "$HOME/Cloud"
      '';
    };
}
