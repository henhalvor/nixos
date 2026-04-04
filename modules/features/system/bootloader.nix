# Default bootloader — systemd-boot for UEFI systems
# Source: nixos/modules/bootloader.nix
# Hosts that need different bootloaders (secure-boot, GRUB) override this.
{...}: {
  flake.nixosModules.bootloader = {...}: {
    boot.loader = {
      grub.enable = false;

      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        # Tolerate non-critical errors (e.g. BOOTX64.EFI owned by firmware)
        graceful = true;
      };

      efi.canTouchEfiVariables = true;
    };

    boot.supportedFilesystems = ["ntfs" "ext4" "vfat"];
  };
}
