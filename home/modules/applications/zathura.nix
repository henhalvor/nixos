{ config, pkgs, ... }:

{
  home.packages = with pkgs; [ zathura ];

  programs.zathura = { enable = true; };

  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = "org.pwmt.zathura.desktop";
  };
}
