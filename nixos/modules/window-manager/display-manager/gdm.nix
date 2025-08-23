{ config, pkgs, userSettings, ... }: {
  services.xserver.displayManager.gdm.enable = true;
}

