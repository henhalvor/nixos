{ config, pkgs, userSettings, windowManager, lib, ... }: {
  imports =
    # Window manager (conditional import)
    (if windowManager == "hyprland" then
      [ ../../nixos/modules/window-manager/hyrpland.nix ]
    else if windowManager == "sway" then
      [ ../../nixos/modules/window-manager/sway.nix ]
    else if windowManager == "gnome" then
    # Need to add gnome specific home config
      [ ../../nixos/modules/window-manager/gnome.nix ]
    else if windowManager == "none" then
      [ ]
    else [
      throw
      "Unsupported window manager in flake's windowManager: ${windowManager}"
    ]) ++ [
      ./hardware-configuration.nix
      ../../nixos/default.nix
      ../../nixos/modules/external-io.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/networking.nix
      ./bootloader.nix
      # window-manager
      ../../nixos/modules/window-manager/default.nix

      # Server connectivity
      ../../nixos/modules/server/ssh.nix
      ../../nixos/modules/server/tailscale.nix

    ];

  # boot.kernelParams = [
  #   "mem_sleep_default=s2idle"
  # ]; # default is "deep" sleep this sets to lighter sleep "s2idle"

  # logitect wireless dongle
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # NVIDIA GPU
  # Use NVIDIA proprietary drivers and automatically detect correct version
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false; # Power-saving mostly applies to laptops
    open = false; # Use proprietary blob (recommended for your GPU)
    nvidiaSettings = true; # Optional: enables `nvidia-settings` GUI tool
  };

  # OPTIONAL: Prevent conflicts with AMD integrated GPU
  boot.kernelParams = [ "modprobe.blacklist=amdgpu" ];

}
