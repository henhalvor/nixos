{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ nautilus gnome.gvfs ];

  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "org.gnome.Nautilus.desktop";
  };
}
