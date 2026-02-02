{
  hostname = "workstation";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";
    lock = null; # null = use session default (hyprlock)
    idle = "none"; # null = use session default (hypridle)
    notifications = null; # null = use session default (hyprpanel for hyprland)

    monitors = [
      # ASUS monitor (portrait, physically on the left)
      "HDMI-A-1,1920x1080@144,0x0,1,transform,1"
      # Samsung Odyssey (main monitor, on the right)
      "DP-1,2560x1440@144,1080x0,1"
    ];

    workspaceRules = [
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-1"
      "3, monitor:DP-1"
      "4, monitor:HDMI-A-1, default:true"
      "5, monitor:HDMI-A-1"
      "6, monitor:HDMI-A-1"
    ];
  };

  hardware = {
    gpu = "nvidia";
    logitech = true;
  };
}
