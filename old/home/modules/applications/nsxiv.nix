
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    nsxiv
  ];

  # Enable mimeapps management to set defaults
  xdg.mimeApps.enable = true;

  # Set nsxiv as default image viewer
  xdg.mimeApps.defaultApplications = {
    "image/png"  = "nsxiv.desktop";
    "image/jpeg" = "nsxiv.desktop";
    "image/gif"  = "nsxiv.desktop";
    "image/bmp"  = "nsxiv.desktop";
    "image/webp" = "nsxiv.desktop";
  };
}
