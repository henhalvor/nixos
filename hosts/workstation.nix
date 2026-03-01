{
  hostname = "workstation";

  desktop = {
    session = "hyprland";
    bar = "waybar";
    lock = "hyprlock"; # null = use session default (hyprlock)
    idle = "none"; # null = use session default (hypridle)
    notifications = "mako"; # null = use session default (hyprpanel for hyprland)
    logout = "none";

    monitors = [
      # ASUS monitor (portrait, physically on the left)
      "HDMI-A-1,1920x1080@144,0x0,1,transform,1"
      # Samsung Odyssey (main monitor, on the right)
      "DP-1,2560x1440@144,1080x0,1"
    ];

    workspaceRules = [
      # ASUS monitor (portrait, physically on the left)
      "1, monitor:HDMI-A-1"
      "3, monitor:HDMI-A-1"

      # Samsung Odyssey (main monitor, on the right)
      "2, monitor:DP-1"
      "4, monitor:DP-1"
      "5, monitor:DP-1"
      "6, monitor:DP-1"

      # Sunshine virtual monitor
      "10, monitor:HEADLESS-1"
    ];
  };

  hardware = {
    gpu = "nvidia";
    logitech = true;
  };
}
