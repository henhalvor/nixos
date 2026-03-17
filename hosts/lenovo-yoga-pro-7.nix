{
  hostname = "lenovo-yoga-pro-7";

  # Session defaults are located in ../lib/desktop.nix
  desktop = {
    session = "niri";
    shell = "noctalia"; # Manages bar, notifications, and logout
    # bar, notifications, and logout are disabled automatically when shell is set

    # Hyprland-specific monitor configuration
    monitors = [
      # ",preferred,auto,1"
      "eDP-1,2560x1600@60,0x0,1.6"
      # "DP-9,2560x1440@144,0x0,1"
      # "DP-8,1920x1080@144,-1080x240,1,transform,1"
    ];

    workspaceRules = [
      "2, monitor:DP-9"
      "3, monitor:DP-9"
      "1, monitor:DP-8"
      "1, monitor:eDP-1"
      "2, monitor:eDP-1"
      "3, monitor:eDP-1"
    ];
  };

  hardware = {
    gpu = "amd";
    logitech = true;
  };
}
