{ config, pkgs, ... }:

{
  systemd.user.services = {
    hyprpaper = {
      Unit = {
        Description = "Hyprland Wallpaper";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
        X-Restart-Trigger =
          "${config.xdg.configFile."hypr/hyprpaper.conf".source}";
      };
      Service = {
        ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install = { WantedBy = [ "graphical-session.target" ]; };
    };

  };
}
