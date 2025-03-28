
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
      ../../nixos/modules/systemd-loginhd.nix

      # window-manager
      ../../nixos/modules/window-manager/default.nix
      ../../nixos/modules/window-manager/gnome.nix
      ../../nixos/modules/window-manager/hyrpland.nix
      ../../nixos/modules/window-manager/sway.nix
    ];
}
