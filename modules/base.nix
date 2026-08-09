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

    # Core system packages
    environment.systemPackages = with pkgs; [
      home-manager
      os-prober
      vim

      # External hard drive tools
      ntfs3g
      dosfstools

      usbutils
      ethtool
    ];

    # Allow insecure qtwebengine (needed by some packages)
    nixpkgs.config.permittedInsecurePackages = [
      "qtwebengine-5.15.19"
    ];
  };
}
