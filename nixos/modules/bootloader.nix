
{ config, pkgs, userSettings, systemSettings, ... }:
{
  # Bootloader configuration
  boot.loader = {
    grub = {
      enable = false;
   };

   # Use systemd-boot instead of grub
    systemd-boot = {
      enable = true;
      # This ensures systemd-boot can handle your generations
      configurationLimit = 10;  # Adjust this number to control how many generations to keep
    };
    
    # EFI settings for UEFI systems
    efi = {
      canTouchEfiVariables = false;
    };
  };


boot.supportedFilesystems = [ "ntfs" "ext4" "vfat" ];


}
