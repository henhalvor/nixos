{ config, pkgs, lib, systemName, ... }:
let
  # Define system-specific configurations
  systemConfigs = {
    lenovo-yoga-pro-7 = {
      enable = true;
      transitions = {
        sunrise = {
          calendar = "*-*-* 06:00:00";
          requests = [ [ "temperature" "6500" ] [ "gamma" "100" ] ];
        };
        sunset = {
          calendar = "*-*-* 22:00:00";
          requests = [[ "temperature" "3500" ]];
        };
      };
    };

    workstation = {
      enable = false;
      transitions = { };
    };
  };

  currentConfig =
    systemConfigs.${systemName} or systemConfigs.lenovo-yoga-pro-7;

in {
  home.packages = with pkgs; [ hyprsunset ];

  services.hyprsunset = {
    enable = currentConfig.enable;
    transitions = currentConfig.transitions;
  };
}

