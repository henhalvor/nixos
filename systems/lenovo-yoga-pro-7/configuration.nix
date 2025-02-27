
{ config, pkgs, userSettings, systemSettings, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../../nixos/default.nix
      ../../nixos/modules/battery.nix
      ../../nixos/modules/amd-graphics.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/bootloader.nix
      ../../nixos/modules/networking.nix
    ];
}
