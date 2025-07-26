{ pkgs, systemName, ... }:
let

  # Define system-specific configurations
  systemConfigs = {
    lenovo-yoga-pro-7 = {
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

    workstation = {
      # timeouts = [{
      #   timeout = 300;
      #   command = "${pkgs.swaylock}/bin/swaylock -fF";
      # }];
      timeouts = [ ];
    };
  };

  currentConfig = systemConfigs.${systemName} or systemConfigs.workstation;

in {
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
    timeouts = currentConfig.timeouts;
  };

}

