{ config, pkgs, ... }: {
  # --- Bootloader Configuration (GRUB for UEFI) ---
 # boot.loader = {
    # Disable systemd-boot
#    systemd-boot.enable = false;

    # Enable interaction with UEFI variables (needed for GRUB EFI install)
#    efi.canTouchEfiVariables = true;
    # NO efiSysMountPoint needed since your ESP is mounted at /boot

    # Enable GRUB
#    grub = {
#      enable = true;
#      efiSupport = true; # Use UEFI installation method
#      device = "nodev"; # REQUIRED for UEFI: Install to ESP, not MBR/PBR
#      useOSProber = true; # Keep if you dual-boot, set to false if not
#    };
#  };

  # --- REMINDER: Initrd Configuration ---
  # Ensure this section is also present and correct in your configuration.nix
  # to avoid the Stage 1 boot error you had before!
  # Adjust the list based on your specific hardware and root filesystem type.
#  boot.initrd.kernelModules = [
#    "nvme" # For your NVMe SSD
#    "xhci_pci" # Often needed for USB keyboard/other devices in initrd
#    "ext4" # Assuming your root filesystem is ext4 - CHANGE if different (e.g., "btrfs")
#    # Add others like "ahci", "sd_mod" if you have SATA devices
 #   # Add "dm_mod", "dm_crypt" if using LVM/LUKS on root
#  ];
 # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

}
