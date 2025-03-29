# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, userSettings, ... }:

{
  # Needed for remote ssh for vscode. Run unpatched dynamic binaries on NixOS.
  programs.nix-ld.enable = true;

  # Enable Vulkan support
  hardware.pulseaudio.support32Bit = true;

  # Configure console keymap
  console.keyMap = "no";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Docker
  virtualisation.docker.enable = true;

  # Enable zsh
  programs.zsh.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    home-manager
    os-prober
    # External hard drive tools
    ntfs3g # If it's an NTFS drive
    dosfstools # If it's FAT/FAT32

    # For controlling external monitor's brightness
    ddcutil
  ];

  # I2C support for monitor control
  hardware.i2c.enable = true;

  # Add i2c group and udev rules + Udev rule for configuring keyboard with VIAL
  users.groups.i2c = { };
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"

    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';

}
