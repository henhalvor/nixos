{ config, pkgs, userSettings, ... }:

{

  home.packages = with pkgs; [
    # Wayland essentials
    wofi # Application launcher
    waybar # Status bar
    # swaync          # Notification daemon
    # swaylock        # Screen locker
    # swayidle        # Idle management daemon
    wl-clipboard # Clipboard manager
    # grim            # Screenshot utility
    # slurp           # Screen region selector
    # wf-recorder     # Screen recording
    # brightnessctl   # Brightness control
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
  };

  # Manage hyprland configuration file
  home.file = {
    ".config/hypr/hyprland.conf".source = ./config/hypr/hyprland.conf;
  };


}





