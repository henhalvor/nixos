
{ config, pkgs, userSettings, systemSettings, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../../nixos/default.nix
      ../../nixos/modules/nvidia-graphics.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/networking.nix
      # Custom bootloader for desktop (using grub + non efi system)
      ./bootloader.nix

      # window-manager
      ../../nixos/modules/window-manager/default.nix
      ../../nixos/modules/window-manager/gnome.nix
      ../../nixos/modules/window-manager/hyrpland.nix
      ../../nixos/modules/window-manager/sway.nix
    ];
}
