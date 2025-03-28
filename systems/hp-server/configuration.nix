
{ config, pkgs, userSettings, systemSettings, ... }:
{
  imports =
    [
      # General system configuration
      ./hardware-configuration.nix
      ../../nixos/default.nix
      ../../nixos/modules/nvidia-graphics.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/bootloader.nix
      ../../nixos/modules/networking.nix

      # Server specific
      ../../nixos/modules/server/default.nix
      ../../nixos/modules/server/ssh.nix
      ../../nixos/modules/server/laptop-server.nix
      ../../nixos/modules/server/server-monitoring.nix
      # ../../nixos/modules/server/cockpit.nix

      # window-manager
      ../../nixos/modules/window-manager/default.nix
      ../../nixos/modules/window-manager/gnome.nix
      ../../nixos/modules/window-manager/hyrpland.nix
      ../../nixos/modules/window-manager/sway.nix
    ];
}
