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
      ../../nixos/modules/gaming.nix
      ../../nixos/modules/virtualization.nix
      # ./bootloader.nix
      ./secure-boot.nix # Secore boot overrides bootloader settings
      # window-manager
      ../../nixos/modules/window-manager/default.nix

      # Server connectivity
      ../../nixos/modules/server/ssh.nix
      ../../nixos/modules/server/tailscale.nix

      # Scripts
      ./scripts/boot-windows.nix

    ];
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

  # All of the usb and bluetooth tweaks may not be necessary, they were added when experiencing usb and bluetooth issues due to hardware change. This was resolved my power cycling the machine, but the tweaks are left in place for now.

  boot.kernelParams = [
    "modprobe.blacklist=amdgpu" # Prevent conflicts with AMD integrated GPU:  Disable AMD integrated GPU since we are using NVIDIA - Linux firmware does not currently support the newest amd IGPU's
    "mem_sleep_default=s2idle" # Set sleep to "lighter sleep" default is "deep" sleep, solves weird graphics bug on displays after deep sleep
    "usbcore.autosuspend=-1" # Disable USB autosuspend
    "usb-storage.delay_use=0" # Remove USB storage delays
    "btusb.enable_autosuspend=0" # Disable Bluetooth autosuspend
  ];

  # Force early USB initialization
  boot.initrd.kernelModules = [ "xhci_pci" "ehci_pci" ];

  # Disable USB power management via udev
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend", ATTR{power/autosuspend}="-1"
  '';

  # Explicitly enable bluetooth support
  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };

  boot.kernelModules = [
    "bluetooth"
    "btusb"
    "btmtk" # MediaTek Bluetooth specifically
    "mt7925e" # Your WiFi driver
    "mt7925"
  ];

  hardware.enableAllFirmware = true;
  hardware.firmware = [ pkgs.linux-firmware ];
  hardware.enableRedistributableFirmware = true;

}
