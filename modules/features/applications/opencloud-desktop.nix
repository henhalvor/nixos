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
    let
      # Stylix selects Kvantum for Qt applications.  OpenCloud Desktop is a
      # Qt 6 application, but its upstream package does not include that style
      # plugin in its own Qt plugin path.  Wrap only this client so it follows
      # the existing desktop theme instead of failing at startup.
      opencloudDesktop = pkgs.symlinkJoin {
        name = "opencloud-desktop-kvantum";
        paths = [ pkgs.opencloud-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencloud \
            --prefix QT_PLUGIN_PATH : ${pkgs.qt6Packages.qtstyleplugin-kvantum}/lib/qt-6/plugins
          wrapProgram $out/bin/opencloudcmd \
            --prefix QT_PLUGIN_PATH : ${pkgs.qt6Packages.qtstyleplugin-kvantum}/lib/qt-6/plugins
        '';
      };
    in
    {
      home.packages = [ opencloudDesktop ];

      home.activation.createOpencloudSyncRoot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p "$HOME/Cloud"
      '';
    };
}
