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
      # The global Qt setup exports QT_STYLE_OVERRIDE=kvantum, but OpenCloud's
      # Qt Quick UI interprets that as a QML style module and aborts because no
      # such module exists.  Keep the native Kvantum plugin available for its
      # widget UI, while removing the incompatible global override.
      opencloudDesktop = pkgs.symlinkJoin {
        name = "opencloud-desktop-kvantum";
        paths = [ pkgs.opencloud-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencloud \
            --unset QT_STYLE_OVERRIDE \
            --prefix QT_PLUGIN_PATH : ${pkgs.qt6Packages.qtstyleplugin-kvantum}/lib/qt-6/plugins
          wrapProgram $out/bin/opencloudcmd \
            --unset QT_STYLE_OVERRIDE \
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
