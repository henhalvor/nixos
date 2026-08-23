# freecad — browser
# Source: home/modules/applications/freecad.nix
# Template B2: HM-only
#
# FreeCAD profile sync via Syncthing-backed ~/Shared:
#
# Workstation -> shared profile, with FreeCAD closed:
#   mkdir -p ~/Shared/FreeCAD-profile/config ~/Shared/FreeCAD-profile/data
#   rsync -a --delete ~/.config/FreeCAD/ ~/Shared/FreeCAD-profile/config/
#   rsync -a --delete ~/.local/share/FreeCAD/ ~/Shared/FreeCAD-profile/data/
#
# Shared profile -> Lenovo, with FreeCAD closed:
#   rsync -a --delete ~/Shared/FreeCAD-profile/config/ ~/.config/FreeCAD/
#   rsync -a --delete ~/Shared/FreeCAD-profile/data/ ~/.local/share/FreeCAD/
{ self, ... }:
{
  flake.nixosModules.freecad =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.freecad ];
    };

  flake.homeModules.freecad =
    {
      pkgs,
      pkgs-unstable,
      ...
    }:
    let
      freecad = pkgs-unstable.freecad;
      freecadXcb = pkgs.symlinkJoin {
        name = "freecad-xcb";
        paths = [ freecad ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm -f $out/share/applications/org.freecad.FreeCAD.desktop
          cp ${freecad}/share/applications/org.freecad.FreeCAD.desktop \
            $out/share/applications/org.freecad.FreeCAD.desktop
          substituteInPlace $out/share/applications/org.freecad.FreeCAD.desktop \
            --replace-fail "Exec=FreeCAD - --single-instance %F" \
                           "Exec=FreeCAD --single-instance %F"

          # Keep the existing XCB/XWayland path. FreeCAD has a native Wayland
          # platform plugin, but it has shown blank 3D views on Niri/Sway. Do
          # not switch this to Wayland without manually testing PartDesign's
          # 3D viewport and task dialogs.
          #
          # FreeCAD is a Qt Widgets application with embedded Python/PySide.
          # Its package wrapper supplies a matched Qt and Python runtime, but
          # desktop-wide Qt and Python variables otherwise leak into it. In
          # particular, Kvantum/qt5ct, mixed Qt 5/Qt 6 plugin paths, and the
          # user Python base were associated with task-dialog teardown
          # instability and SIGSEGVs in FreeCAD's Qt hover handling. Strip
          # those variables in
          # this outer wrapper before FreeCAD's own wrapper adds its runtime.
          wrapProgram $out/bin/FreeCAD \
            --set QT_QPA_PLATFORM xcb \
            --set SDL_VIDEODRIVER x11 \
            --unset QT_STYLE_OVERRIDE \
            --unset QT_QPA_PLATFORMTHEME \
            --unset QT_PLUGIN_PATH \
            --unset QML2_IMPORT_PATH \
            --unset PYTHONPATH \
            --unset PYTHONUSERBASE
          wrapProgram $out/bin/freecad \
            --set QT_QPA_PLATFORM xcb \
            --set SDL_VIDEODRIVER x11 \
            --unset QT_STYLE_OVERRIDE \
            --unset QT_QPA_PLATFORMTHEME \
            --unset QT_PLUGIN_PATH \
            --unset QML2_IMPORT_PATH \
            --unset PYTHONPATH \
            --unset PYTHONUSERBASE
        '';
      };
    in
    {
      # FreeCAD's Render workbench writes POV-Ray scene files, while POV-Ray
      # itself performs the render. Configure the profile path to `povray` in
      # FreeCAD's Render preferences after activation.
      home.packages = [ freecadXcb pkgs.povray ];
    };
}
