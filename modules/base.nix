# Base system configuration — shared across all hosts
# Source: nixos/default.nix + inline config from lib/mk-nixos-system.nix
{...}: {
  flake.nixosModules.base = {pkgs, ...}: {
    # System platform
    nixpkgs.hostPlatform = "x86_64-linux";

    # Nix settings
    nix.settings.experimental-features = ["nix-command" "flakes"];
    nixpkgs.config.allowUnfree = true;

    # Locale & timezone (shared across all hosts)
    time.timeZone = "Europe/Oslo";
    i18n.defaultLocale = "en_US.UTF-8";

    # Console keymap
    console.keyMap = "no";

    # Run unpatched dynamic binaries on NixOS (needed for vscode remote ssh)
    programs.nix-ld.enable = true;

    # Enable zsh system-wide (required for user shells)
    programs.zsh.enable = true;

    # Docker
    virtualisation.docker.enable = true;

    # Virtual filesystem support (for GVFS, used by Nautilus)
    services.gvfs.enable = true;
    programs.gnome-disks.enable = true;

    # Printing (basic — printer feature adds scanner/avahi)
    services.printing.enable = true;

    # Core system packages
    environment.systemPackages = with pkgs; [
      home-manager
      os-prober
      vim

      # External hard drive tools
      ntfs3g
      dosfstools

      # External monitor brightness control
      ddcutil

      usbutils
      ethtool
    ];

    # I2C support for monitor control
    hardware.i2c.enable = true;
    users.groups.i2c = {};

    # Udev rules: i2c access + VIAL keyboard
    services.udev.extraRules = ''
      KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    '';

    # Allow insecure qtwebengine (needed by some packages)
    nixpkgs.config.permittedInsecurePackages = [
      "qtwebengine-5.15.19"
    ];
  };
}
