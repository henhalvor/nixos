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
    ];
}
