{ config, pkgs, userSettings, zen-browser, ... }:

{
  # Install Zen Browser via home.packages
  home.packages = [
    zen-browser.packages.${userSettings.system}.default
  ];


}
