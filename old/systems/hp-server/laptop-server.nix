

{ config, pkgs, userSettings, ... }: {

  # Disable sleep/hibernation when lid is closed
  services.logind = {
    lidSwitch = "ignore";
    lidSwitchExternalPower = "ignore";
    extraConfig = ''
      HandleLidSwitch=ignore
      HandleLidSwitchExternalPower=ignore
      HandleLidSwitchDocked=ignore
      IdleAction=ignore
    '';
  };

  # Keep the system awake
  powerManagement = {
    enable = true;
    powertop.enable = false; # Disable powertop to prevent auto power saving
    cpuFreqGovernor =
      "performance"; # Use performance governor instead of powersave
  };

}
