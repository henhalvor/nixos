{ config, pkgs, ... }: {
  # Enables auto mounting external hard drives
  services.udiskie = {
    enable = true;
    notify = true;
    tray = "auto";
    automount = true;
  };
}
