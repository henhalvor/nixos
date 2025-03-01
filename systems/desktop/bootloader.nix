{ config, pkgs, userSettings, systemSettings, ... }:
{

  # Bootloader configuration
  boot.loader = {
    grub = {
      enable = true;
      useOSProber = true;
      efiSupport = false;
      efiInstallAsRemovable = false;
      # For BIOS systems (desktop)
      device = "/dev/sda";
    };
    # EFI settings for UEFI systems
    efi = {
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot/efi";
    };
  };

}
