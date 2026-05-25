# freecad — browser
# Source: home/modules/applications/freecad.nix
# Template B2: HM-only
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
