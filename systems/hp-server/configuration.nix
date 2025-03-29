{ config, pkgs, userSettings, systemSettings, ... }: {
  imports =
    # Window manager (conditional import)
    (if systemSettings.windowManager == "hyprland" then
      [ ../../nixos/modules/window-manager/hyrpland.nix ]
    else if systemSettings.windowManager == "sway" then
      [ ../../nixos/modules/window-manager/sway.nix ]
    else if systemSettings.windowManager == "gnome" then
    # Need to add gnome specific home config
      [ ../../nixos/modules/window-manager/gnome.nix ]
    else if systemSettings.windowManager == "none" then
      [ ]
    else [
      throw
      "Unsupported window manager in flake's systemSettings.windowManager: ${systemSettings.windowManager}"
    ]) ++ [
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
    ];
}
