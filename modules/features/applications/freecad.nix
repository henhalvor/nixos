# freecad — thin bridge to the FreeCAD Launcher flake
#
# FreeCAD stable and weekly builds are now owned by the launcher, which stores
# them as mutable user-owned AppImages under XDG data:
#   $XDG_DATA_HOME/freecad-launcher/versions/
#
# The launcher preserves the existing profile locations, so the Syncthing-backed
# profile sync still applies:
#
# Workstation -> shared profile, with FreeCAD closed:
#   mkdir -p ~/Shared/FreeCAD-profile/config ~/Shared/FreeCAD-profile/data
#   rsync -a --delete ~/.config/FreeCAD/ ~/Shared/FreeCAD-profile/config/
#   rsync -a --delete ~/.local/share/FreeCAD/ ~/Shared/FreeCAD-profile/data/
#
# Shared profile -> Lenovo, with FreeCAD closed:
#   rsync -a --delete ~/Shared/FreeCAD-profile/config/ ~/.config/FreeCAD/
#   rsync -a --delete ~/Shared/FreeCAD-profile/data/ ~/.local/share/FreeCAD/
#
# Install/update FreeCAD releases from the launcher window or with:
#   freecad-launcher launch --channel stable
#   freecad-launcher launch --channel weekly
{ self, inputs, ... }:
{
  # The NixOS side enables Chromium's setuid sandbox and installs the launcher;
  # the Home Manager side installs the package, its main desktop entry, and the
  # POV-Ray render helper. The option name is unchanged so host imports do not
  # churn.
  flake.nixosModules.freecad =
    { ... }:
    {
      imports = [ inputs.freecad-launcher.nixosModules.default ];
      services.freecad-launcher.enable = true;

      home-manager.sharedModules = [ self.homeModules.freecad ];
    };

  flake.homeModules.freecad =
    { pkgs, ... }:
    {
      imports = [ inputs.freecad-launcher.homeModules.default ];
      programs.freecad-launcher.enable = true;

      # FreeCAD's Render workbench writes POV-Ray scene files, while POV-Ray
      # itself performs the render. Configure the profile path to `povray` in
      # FreeCAD's Render preferences after activation.
      home.packages = [ pkgs.povray ];
    };
}
