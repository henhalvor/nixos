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

  # Mako notification daemon - Stylix handles the theming
  # Enable based on desktop.notifications setting
  services.mako = {
    enable = desktop.notifications == "mako";
    # Let Stylix handle colors and fonts
    # Only configure behavior settings
    settings = {
      default-timeout = 5000;
      anchor = "top-right";
      max-visible = 5;
    };
  };
}
