# Lenovo Yoga Pro 7 — hardware configuration
# Source: systems/lenovo-yoga-pro-7/hardware-configuration.nix (nixos-generate-config)
{...}: {
  flake.nixosModules.lenovoYogaPro7Hardware = {
    config,
    lib,
    modulesPath,
    ...
  }: {
    imports = [(modulesPath + "/installer/scan/not-detected.nix")];

    boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-amd"];
    boot.extraModulePackages = [];

    fileSystems."/" = {
      device = "/dev/disk/by-uuid/6d349d18-9193-4deb-a5ab-937d306da763";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/BA35-D34F";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    # Persistent swap is intentionally plaintext because the root ext4 filesystem
    # is not encrypted. See docs/LENOVO-YOGA-PRO-7-SLEEP-HIBERNATION.md for the
    # accepted security risk and the required recovery procedure.
    swapDevices = [
      {
        device = "/swapfile";
        # 32 GiB covers the installed memory with a small hibernation margin.
        size = 32768;
      }
    ];

    # The resume device is the partition containing /swapfile. The offset is in
    # 4 KiB pages and was recorded from `filefrag -v /swapfile` after creation.
    # Recalculate it before changing, deleting, or recreating the swapfile.
    boot.resumeDevice = "/dev/disk/by-uuid/6d349d18-9193-4deb-a5ab-937d306da763";
    boot.kernelParams = [ "resume_offset=5347328" ];

    networking.useDHCP = lib.mkDefault true;
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
