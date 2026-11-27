# Luciole — Noctalia's native Wayland file manager, set as the default
# https://github.com/noctalia-dev/luciole
#
# Default for folders (inode/directory), the org.freedesktop.FileManager1
# D-Bus service ("show in folder" from browsers and other apps), and the
# xdg-desktop-portal Open/Save picker. Replaces nautilus.nix on the desktop
# hosts (that module is kept, unused).
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.luciole = {pkgs, ...}: let
    # Same build Luciole's HM module installs (from the Noctalia cache).
    luciole = inputs.luciole.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in {
    home-manager.sharedModules = [self.homeModules.luciole];

    # Trash, removable drives and remote locations (sftp, smb) go through
    # GVfs. desktopCommon enables it too; set here so the module stands alone.
    services.gvfs.enable = true;

    # Luciole implements only FileChooser. Everything else stays on the
    # default (GTK, from desktopCommon), which is also the picker fallback.
    # This lands in /etc/xdg/xdg-desktop-portal/portals.conf, which niri
    # sessions read before the niri-portals.conf shipped in niri's package.
    xdg.portal = {
      enable = true;
      extraPortals = [luciole];
      config.common."org.freedesktop.impl.portal.FileChooser" = [
        "luciole"
        "gtk"
      ];
    };
  };

  flake.homeModules.luciole = {config, ...}: let
    package = config.programs.luciole.package;
  in {
    # Luciole's module defaults programs.luciole.package to its own build.
    imports = [inputs.luciole.homeModules.default];

    programs.luciole.enable = true;

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications."inode/directory" = "dev.noctalia.luciole.desktop";

    # Installing Luciole does not claim FileManager1; a user service file
    # under ~/.local/share takes precedence over any other provider.
    xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".source = "${package}/share/dbus-1/services/dev.noctalia.luciole.FileManager1.service";
  };
}
