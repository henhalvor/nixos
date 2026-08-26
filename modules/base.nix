# Base system configuration — shared across all hosts
# Source: nixos/default.nix + inline config from lib/mk-nixos-system.nix
{ ... }:
{
  flake.nixosModules.base =
    { pkgs, ... }:
    {
      # System platform
      nixpkgs.hostPlatform = "x86_64-linux";

      # Nix settings
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
      nixpkgs.config.allowUnfree = true;

      # Locale & timezone (shared across all hosts)
      time.timeZone = "Europe/Oslo";
      i18n.defaultLocale = "en_US.UTF-8";

      # Console keymap
      console.keyMap = "no";

      # Enable zsh system-wide (required for user shells)
      programs.zsh.enable = true;

      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          glib
          nss
          nspr
          ffmpeg
          dbus
          atk
          at-spi2-atk
          at-spi2-core
          cups
          cairo
          gtk3
          pango
          xorg.libX11
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXrandr
          libgbm
          libglvnd
          mesa
          expat
          libxcb
          libxkbcommon
          alsa-lib
        ];
      };

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
