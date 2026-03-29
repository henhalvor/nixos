{ config, lib, pkgs, desktop, userSettings, ... }:
{
  home.packages = with pkgs; [
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
