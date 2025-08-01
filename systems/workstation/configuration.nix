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
      # ../../nixos/modules/battery.nix
      # ./amd-graphics.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/networking.nix
      # ../../nixos/modules/systemd-loginhd.nix
      ./bootloader.nix
      # window-manager
      ../../nixos/modules/window-manager/default.nix

      # Server connectivity
      ../../nixos/modules/server/ssh.nix
      ../../nixos/modules/server/tailscale.nix

    ];

  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # Keep the s2idle setting
  # boot.kernelParams = [
  #   "mem_sleep_default=s2idle"
  # ]; # default is "deep" sleep this sets to lighter sleep "s2idle"

  # logitect wireless dongle
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # Sets the kernel version to the latest kernel to make the usage of the iGPU possible if your kernel version is too old
  # Disables scatter/gather which was introduced with kernel version 6.2
  # It produces completely white or flashing screens when enabled while using the iGPU of Ryzen 7000-series CPUs (Raphael)
  # This issue is not seen in kernel 6.6 or newer versions

  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot = lib.mkMerge [
    (lib.mkIf (lib.versionOlder pkgs.linux.version "6.1") {
      kernelPackages = pkgs.linuxPackages_latest;
    })

    (lib.mkIf
      ((lib.versionAtLeast config.boot.kernelPackages.kernel.version "6.2")
        && (lib.versionOlder config.boot.kernelPackages.kernel.version "6.6")) {
          kernelParams = [ "amdgpu.sg_display=0" ];
        })
  ];

  # Add the missing power management
  # powerManagement.enable = true;

}
