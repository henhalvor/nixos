{
  hostname = "lenovo-yoga-pro-7";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";
    lock = null;  # null = use session default (hyprlock)
    idle = null;  # null = use session default (hypridle)
    notifications = null;  # null = use session default (hyprpanel for hyprland)

    # Hyprland-specific monitor configuration
    monitors = [
      ",preferred,auto,1"
      "eDP-1,2560x1600@60,0x0,1.6"
      "DP-9,2560x1440@144,0x0,1"
      "DP-8,1920x1080@144,-1080x240,1,transform,1"
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
