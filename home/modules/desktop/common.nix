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
  # Don't enable mako when using hyprpanel (it has its own notification daemon)
  services.mako = {
    enable = desktop.bar != "hyprpanel";
    # Let Stylix handle colors and fonts
    # Only configure behavior settings
    defaultTimeout = 5000;
    anchor = "top-right";
    maxVisible = 5;
  };
}
