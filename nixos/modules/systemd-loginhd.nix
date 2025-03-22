{ config, lib, pkgs, ... }:

{
  services.logind = {
    lidSwitch = "suspend";
    lidSwitchExternalPower = "lock";
    extraConfig = ''
      # Allow lid close handling
      HandleLidSwitch=suspend
      HandleLidSwitchExternalPower=lock
      
      # Don't let systemd kill things too aggressively
      KillUserProcesses=no
      
      # Increase timeout to give processes a chance to handle suspend/resume
      InhibitDelayMaxSec=5
    '';
  };
  
  # Ensure logind can communicate with Hyprland
  security.pam.services.login.enableGnomeKeyring = true;
  security.polkit.enable = true;
}
