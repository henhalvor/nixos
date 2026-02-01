{
  hostname = "workstation";

  desktop = {
    session = "hyprland";
    bar = "hyprpanel";
    lock = null;  # null = use session default (hyprlock)
    idle = null;  # null = use session default (hypridle)

    monitors = [
      "DP-1,3440x1440@144,0x0,1"
      "DP-2,2560x1440@144,3440x0,1"
    ];

    workspaceRules = [
      "1, monitor:DP-1, default:true"
      "2, monitor:DP-1"
      "3, monitor:DP-1"
      "4, monitor:DP-2, default:true"
      "5, monitor:DP-2"
    ];
  };

  hardware = {
    gpu = "nvidia";
    logitech = true;
  };
}
