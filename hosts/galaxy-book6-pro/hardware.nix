# Samsung Galaxy Book6 Pro — hardware configuration
#
# PLACEHOLDER: NixOS has not been installed on this machine yet. The values
# below only exist so the flake evaluates and builds before install. Replace
# this module's body with the output of `nixos-generate-config` (including
# swap and resume settings) before the first `nixos-rebuild switch`.
# See docs/plans/GALAXY-BOOK6-PRO-SETUP.md.
{...}: {
  flake.nixosModules.galaxyBook6ProHardware = {
    config,
    lib,
    modulesPath,
    ...
  }: {
    imports = [(modulesPath + "/installer/scan/not-detected.nix")];

    boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-intel"];
    boot.extraModulePackages = [];

    # PLACEHOLDER: replace with the real UUIDs after install.
    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    # PLACEHOLDER: add a swapfile sized to RAM plus boot.resumeDevice and
    # resume_offset after install, as on the Lenovo, for suspend-then-hibernate.
    swapDevices = [];

    networking.useDHCP = lib.mkDefault true;
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
