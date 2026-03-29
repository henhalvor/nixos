{ config, lib, pkgs, ... }:
{
  # Mako notification daemon - Stylix handles the theming
  services.mako = {
    enable = true;
    # Let Stylix handle colors and fonts
    # Only configure behavior settings
    settings = {
      default-timeout = 5000;
      anchor = "top-right";
      max-visible = 5;
    };
  };

  home.packages = with pkgs; [
    libnotify  # For notify-send command
    mako
  ];
}
