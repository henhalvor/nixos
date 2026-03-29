{
  config,
  pkgs,
  userSettings,
  desktop,
  hostConfig,
  lib,
  ...
}: {
  imports = [
    # General system configuration
    ./hardware-configuration.nix
    ../../nixos/default.nix
    ../../nixos/modules/nvidia-graphics.nix
    ../../nixos/modules/pipewire.nix
    ../../nixos/modules/bluetooth.nix
    ../../nixos/modules/networking.nix

    ./bootloader.nix

    # Server specific
    ../../nixos/modules/server/default.nix
    ../../nixos/modules/server/ssh.nix
    ../../nixos/modules/server/server-monitoring.nix
    ../../nixos/modules/server/tailscale.nix
    ./laptop-server.nix
    # ../../nixos/modules/server/cockpit.nix
  ];

  programs.dconf.enable = true;
}
