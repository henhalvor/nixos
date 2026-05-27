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
    { pkgs, ... }:
    let
      freecadXcb = pkgs.symlinkJoin {
        name = "freecad-xcb";
        paths = [ pkgs.freecad ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm -f $out/share/applications/org.freecad.FreeCAD.desktop
          cp ${pkgs.freecad}/share/applications/org.freecad.FreeCAD.desktop \
            $out/share/applications/org.freecad.FreeCAD.desktop
          substituteInPlace $out/share/applications/org.freecad.FreeCAD.desktop \
            --replace-fail "Exec=FreeCAD - --single-instance %F" \
                           "Exec=FreeCAD --single-instance %F"

          wrapProgram $out/bin/FreeCAD \
            --set QT_QPA_PLATFORM xcb \
            --set SDL_VIDEODRIVER x11
          wrapProgram $out/bin/freecad \
            --set QT_QPA_PLATFORM xcb \
            --set SDL_VIDEODRIVER x11
        '';
      };
    in
    {
      home.packages = [ freecadXcb ];
    };
}
