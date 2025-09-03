{ config, pkgs, ... }: {
  # Bootloader.
  # Config here is overridden by secure-boot.nix if that module is imported in ./configuration.nix.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Include efibootmgr to manage UEFI boot entries. 
  # Allows `sudo efibootmgr -v` too see boot entries. 
  # And `sudo efibootmgr --bootnext 0001` to boot into windows on next restart (this makes it possible to avoid having to change boot order in bios in order to switch systems).
  environment.systemPackages = with pkgs; [ efibootmgr ];

}
