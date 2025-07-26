{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ nautilus ];

  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = "org.gnome.Nautilus.desktop";
  };
}
