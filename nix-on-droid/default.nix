{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Import theme definitions
  themeConfig = import ./theme.nix;
  
  # Select theme (can be changed to any theme from theme.nix)
  selectedTheme = "gruvbox-dark-hard";  # Options: catppuccin-mocha, catppuccin-macchiato, nord, dracula, gruvbox-dark-medium, gruvbox-dark-hard, rose-pine-moon
  
  terminalColors = themeConfig.themes.${selectedTheme};
in
{
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

  # Android integration - Enable opening links and files
  android-integration = {
    termux-open-url.enable = true;  # Open URLs in Android browser
    xdg-open.enable = true;          # Provides xdg-open command (standard Linux)
    termux-reload-settings.enable = true;  # Reload terminal settings without restart
  };

  # Set default shell to zsh
  user.shell = "${pkgs.zsh}/bin/zsh";

  # Set terminal font to Hack Nerd Font
  terminal.font = "${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/HackNerdFont-Regular.ttf";

  # Set terminal colors from theme
  terminal.colors = terminalColors;

  # Disable virtual keyboard extra keys row
  environment.etc."termux/termux.properties".text = ''
    # Disable the extra keys row above keyboard
    extra-keys = []
  '';

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
        username = "nix-on-droid";
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
# How to use ephemeral environment
# nix shell nixpkgs#cmatrix

