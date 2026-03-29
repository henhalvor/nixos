

{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ gthumb ];

  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
    "image/png" = "org.gnome.gThumb.desktop";
    "image/jpeg" = "org.gnome.gThumb.desktop";
    "image/gif" = "org.gnome.gThumb.desktop";
    "image/bmp" = "org.gnome.gThumb.desktop";
    "image/webp" = "org.gnome.gThumb.desktop";
  };
}

