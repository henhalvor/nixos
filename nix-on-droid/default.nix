{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  # Essential system packages
  environment.packages = with pkgs; [
    vim # Fallback editor
    git
    openssh
    wget
    curl
  ];

  # Backup existing files instead of failing
  environment.etcBackupExtension = ".bak";

  # System version
  system.stateVersion = "24.05";

  # Enable flakes
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Time zone
  time.timeZone = "Europe/Oslo";

  environment.sessionVariables = {
    HOSTNAME = "galaxy-tab-s10-ultra"; # or whatever you prefer
  };

  # Set default shell to zsh
  user.shell = "${pkgs.zsh}/bin/zsh";

  # Set terminal font to Hack Nerd Font
  terminal.font = "${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/HackNerdFont-Regular.ttf";

  # Home-manager integration
  home-manager = {
    config = ../users/henhal-android/home.nix;
    backupFileExtension = "hm-bak";
    useGlobalPkgs = true;

    extraSpecialArgs = {
      inherit pkgs;
      inherit (inputs) nvf nvim-nix stylix;

      # Use unstable packages for neovim
      unstable = import inputs.nixpkgs-unstable {
        system = "aarch64-linux";
        config.allowUnfree = true;
      };

      # Use same pkgs for pkgs24-11 (can be changed if needed)
      pkgs24-11 = import inputs.nixpkgs-24-11 {
        system = "aarch64-linux";
        config.allowUnfree = true;
      };

      system = "aarch64-linux";

      userSettings = {
        username = "henhal";
        name = "Henrik";
        email = "henhalvor@gmail.com";
        homeDirectory = config.user.home;
      };

      inputs = {
        inherit (inputs) nvf nvim-nix stylix;
      };
    };
  };
}
