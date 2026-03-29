{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ mpv ];

  programs.mpv.enable = true;

  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
    "video/mp4" = "mpv.desktop";
    "video/webm" = "mpv.desktop";
    "video/x-matroska" = "mpv.desktop";
    "audio/mpeg" = "mpv.desktop";
    "audio/ogg" = "mpv.desktop";
    "audio/wav" = "mpv.desktop";
    # Add more mime types as you like
  };
}

