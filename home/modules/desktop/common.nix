{ config, lib, pkgs, desktop, userSettings, ... }:
{
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    grim
    slurp
    swappy
    libnotify
    playerctl
    brightnessctl
    pamixer
  ];

  xdg.enable = true;

  home.sessionVariables = {
    TERMINAL = userSettings.term;
    BROWSER = userSettings.browser;
  };
}
