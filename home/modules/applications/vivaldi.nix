{ config, lib, pkgs, ... }:

{
  # Enable Vivaldi and its features
  programs.vivaldi = {
    enable = true;
    package = pkgs.vivaldi;  # You could also use vivaldi-ffmpeg-codecs for better media support
    
    # Command line arguments passed to Vivaldi on startup
    commandLineArgs = [
      "--force-dark-mode"               # Enables dark mode regardless of system theme
      "--enable-features=UseOzonePlatform"  # Better Wayland support
      "--ozone-platform=wayland"        # Native Wayland support
      "--enable-features=VaapiVideoDecoder" # Hardware video acceleration
      "--disable-features=UseChromeOSDirectVideoDecoder"  # Prevents conflicts with VAAPI
    ];
  };

  # Additional packages that enhance Vivaldi's functionality
  home.packages = with pkgs; [
    vivaldi-ffmpeg-codecs  # Additional codec support for better media playback
    widevine-cdm          # Required for streaming services like Netflix
  ];

  # Optional: Configure XDG MIME types to make Vivaldi the default browser
  # xdg.mimeApps = {
  #   enable = true;
  #   defaultApplications = {
  #     "text/html" = [ "vivaldi-stable.desktop" ];
  #     "x-scheme-handler/http" = [ "vivaldi-stable.desktop" ];
  #     "x-scheme-handler/https" = [ "vivaldi-stable.desktop" ];
  #     "x-scheme-handler/chrome" = [ "vivaldi-stable.desktop" ];
  #     "application/x-extension-htm" = [ "vivaldi-stable.desktop" ];
  #     "application/x-extension-html" = [ "vivaldi-stable.desktop" ];
  #     "application/x-extension-shtml" = [ "vivaldi-stable.desktop" ];
  #     "application/xhtml+xml" = [ "vivaldi-stable.desktop" ];
  #     "application/x-extension-xhtml" = [ "vivaldi-stable.desktop" ];
  #     "application/x-extension-xht" = [ "vivaldi-stable.desktop" ];
  #   };
  # };
}
