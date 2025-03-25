
{ pkgs, ... }:

{
  home.packages = [ pkgs.kanshi ];

  services.kanshi = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = [
  # { include = "path/to/included/files"; }
  { output.criteria = "eDP-1";
    output.scale = 1.6;
  }
  { profile.name = "undocked";
    profile.outputs = [
      {
        criteria = "eDP-1";
        mode = "2560x1600@90Hz";
        status = "enable";
      }
    ];
  }
  { profile.name = "docked";
    profile.outputs = [
      {
        criteria = "eDP-1";
        status = "disable";
      }
      {
        criteria = "Samsung Odyssey DP-9";
        mode = "2560x1440@144Hz";
        position = "0,0";
        status = "enable";
      }
      {
        criteria = "ASUS DP-8";
        mode = "1920x1080@144Hz";
        position = "-1080,240";
        transform = "90";
        status = "enable";
      }
    ];
  }
];
  };

}
