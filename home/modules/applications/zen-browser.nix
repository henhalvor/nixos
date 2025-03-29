{ config, pkgs, system, zen-browser, ... }:

{
  # Install Zen Browser via home.packages
  home.packages = [ zen-browser.packages.${system}.default ];

  #   xdg.mimeApps = {
  #     enable = true;
  #     defaultApplications = {
  # "application/x-extension-htm" = ["userapp-Zen-CD5312.desktop"];
  # "application/x-extension-html" = ["userapp-Zen-CD5312.desktop"];
  # "application/x-extension-shtml" = ["userapp-Zen-CD5312.desktop"];
  # "application/x-extension-xht" = ["userapp-Zen-CD5312.desktop"];
  # "application/xhtml+xml" = ["userapp-Zen-CD5312.desktop"];
  # "text/html" = ["userapp-Zen-CD5312.desktop"];
  # "x-scheme-handler/http" = ["userapp-Zen-CD5312.desktop"];
  # "x-scheme-handler/https" = ["userapp-Zen-CD5312.desktop"];
  # "x-scheme-handler/chrome" = ["userapp-Zen-CD5312.desktop"];
  # "application/x-extension-xhtml" = ["userapp-Zen-CD5312.desktop"];
  #    };
  #   };
  #
}
