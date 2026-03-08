{
  config,
  pkgs,
  userSettings,
  desktop,
  hostConfig,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../nixos/default.nix
    ../../nixos/modules/external-io.nix
    ../../nixos/modules/pipewire.nix
    ../../nixos/modules/bluetooth.nix
    ../../nixos/modules/bootloader.nix
    ../../nixos/modules/networking.nix
    ../../nixos/modules/printer.nix
    ../../nixos/modules/systemd-loginhd.nix
    ../../nixos/modules/virtualization.nix
    ../../nixos/modules/syncthing.nix
    ./amd-graphics.nix
    ./battery.nix

    # Server connectivity
    ../../nixos/modules/server/ssh.nix
    ../../nixos/modules/server/tailscale.nix

    # Android development
    ../../nixos/modules/android.nix
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Hardware configuration based on hostConfig
  hardware.logitech.wireless.enable = hostConfig.hardware.logitech or false;
  hardware.logitech.wireless.enableGraphical = hostConfig.hardware.logitech or false;

  # Fixes battery percentage in hyprpanel
  services.upower.enable = true;

  # Drivers for usb-c to ethernet adapter
  boot.kernelModules = ["ax88179_178a"];
}
