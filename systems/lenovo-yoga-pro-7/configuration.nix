{ config, pkgs, userSettings, windowManager, ... }: {
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
      ../../nixos/modules/bootloader.nix
      ../../nixos/modules/networking.nix
      ../../nixos/modules/printer.nix
      ../../nixos/modules/systemd-loginhd.nix
      ../../nixos/modules/syncthing.nix
      ./amd-graphics.nix
      ./battery.nix
      # window-manager
      ../../nixos/modules/window-manager/default.nix

      # Server connectivity
      ../../nixos/modules/server/ssh.nix
      ../../nixos/modules/server/tailscale.nix

      # Android development
      ../../nixos/modules/android.nix

    ];

  # logitect wireless dongle
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # Fixes battery percentage in hyprpanel
  services.upower.enable = true;

  # Drivers for usb-c to ethernet adapter
  boot.kernelModules = [ "ax88179_178a" ];
}
