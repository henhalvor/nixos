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
      # ../../nixos/modules/battery.nix
      ./amd-graphics.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/networking.nix
      ../../nixos/modules/systemd-loginhd.nix
      ./bootloader.nix
      # window-manager
      ../../nixos/modules/window-manager/default.nix

      # Server connectivity
      ../../nixos/modules/server/tailscale.nix
    ];

  # logitect wireless dongle
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # Keep the s2idle setting
  boot.kernelParams = [ "mem_sleep_default=s2idle" ]; # default is "deep" sleep this sets to lighter sleep "s2idle"

  # Add the missing power management
  powerManagement.enable = true;

  # Fix USB wake-up
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="0040", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="03", ATTR{power/wakeup}="enabled"
  '';

}
