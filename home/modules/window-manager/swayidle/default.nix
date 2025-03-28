{ pkgs, ... }:

{
  home.packages = [ pkgs.swayidle ];

  services.swayidle = {
    enable = true;
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.swaylock}/bin/swaylock -fF";
      }
      {
        event = "lock";
        command = "${pkgs.swaylock}/bin/swaylock -fF";
      }
    ];
    timeouts = [
      {
        timeout = 180;
        command = "${pkgs.swaylock}/bin/swaylock -fF";
      }
      {
        timeout = 300;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
  };

}

