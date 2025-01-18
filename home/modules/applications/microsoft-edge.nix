{ config, lib, pkgs, ... }:

let
  # Create a wrapper with a unique name
  edge-wayland = pkgs.writeShellScriptBin "microsoft-edge-wayland" ''
    exec ${pkgs.microsoft-edge}/bin/microsoft-edge \
      --ozone-platform=wayland \
      --enable-features=UseOzonePlatform,VaapiVideoDecoder \
      --use-gl=desktop \
      --ignore-gpu-blocklist \
      --enable-gpu-rasterization \
      --enable-zero-copy \
      --force-dark-mode \
      "$@"
  '';
in
{
  # Install Edge and our wrapper
  home.packages = with pkgs; [
    microsoft-edge
    edge-wayland
  ];

  # Set up Edge as the default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "microsoft-edge-wayland.desktop" ];
      "application/xhtml+xml" = [ "microsoft-edge-wayland.desktop" ];
      "x-scheme-handler/http" = [ "microsoft-edge-wayland.desktop" ];
      "x-scheme-handler/https" = [ "microsoft-edge-wayland.desktop" ];
      "application/x-extension-htm" = [ "microsoft-edge-wayland.desktop" ];
      "application/x-extension-html" = [ "microsoft-edge-wayland.desktop" ];
      "application/x-extension-shtml" = [ "microsoft-edge-wayland.desktop" ];
      "application/x-extension-xht" = [ "microsoft-edge-wayland.desktop" ];
    };
  };

  # Create a desktop entry that uses our Wayland-optimized wrapper
  xdg.desktopEntries.microsoft-edge-wayland = {
    name = "Edge (Wayland)";
    genericName = "Web Browser";
    exec = "microsoft-edge-wayland %U";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "text/html"
      "application/xhtml+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    icon = "microsoft-edge";
  };

     # Hide the original Microsoft Edge
    xdg.desktopEntries.microsoft-edge = {
      name = "Microsoft Edge";
      exec = "microsoft-edge %U";
      noDisplay = true;  # This hides it from application launchers
    };
}
