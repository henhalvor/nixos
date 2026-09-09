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
      # OpenCloud ships a self-contained Qt runtime.  The desktop session's
      # Qt variables mix profile-wide Qt 5/6 paths into that runtime, which can
      # make its Qt Quick imports resolve against an incompatible Qt version.
      opencloudDesktop = pkgs.symlinkJoin {
        name = "opencloud-desktop-isolated-qt";
        paths = [ pkgs.opencloud-desktop ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/opencloud \
            --unset QT_STYLE_OVERRIDE \
            --unset QT_QPA_PLATFORMTHEME \
            --unset QT_PLUGIN_PATH \
            --unset QML2_IMPORT_PATH
          wrapProgram $out/bin/opencloudcmd \
            --unset QT_STYLE_OVERRIDE \
            --unset QT_QPA_PLATFORMTHEME \
            --unset QT_PLUGIN_PATH \
            --unset QML2_IMPORT_PATH
        '';
      };
    in
    {
      home.packages = [ opencloudDesktop ];

      # OpenCloud's own autostart writer records the resolved package binary as
      # an absolute store path.  That bypasses the wrapper above and becomes
      # stale after upgrades.  Keep login startup pointed at the profile name.
      xdg.configFile."autostart/OpenCloud.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=OpenCloud Desktop
          GenericName=File Synchronizer
          Exec=opencloud
          Terminal=false
          Icon=opencloud
          Categories=Network
          StartupNotify=false
          X-GNOME-Autostart-enabled=true
          X-GNOME-Autostart-Delay=10
        '';
      };

      home.activation.createOpencloudSyncRoot = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p "$HOME/Cloud"
      '';
    };
}
