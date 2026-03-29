# Basic CLI tools for Android/Termux environments
# Source: nix-on-droid/modules/basic-cli-tools.nix
{ ... }: {
  flake.homeModules.basicCliTools = { pkgs, ... }: {
    home.packages = with pkgs; [
      # Search tools
      ripgrep gnugrep
      # File tools
      findutils which file
      # Text processing
      gnused gawk
      # Network tools
      inetutils curl wget
      # Compression
      gzip bzip2 xz zip unzip
      # System utilities
      procps less man coreutils
      # Diff and patch
      diffutils patch
    ];
  };
}
