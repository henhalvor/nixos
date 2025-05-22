{ config, pkgs, ... }:

{
  #
  # Neovim configuration
  #

  # programs.neovim = {
  #   enable = true;
  #   # This automatically sets EDITOR and VISUAL to nvim
  #   defaultEditor = true;
  #
  #   # You can add other Neovim-specific configurations here
  #   # For example:
  #   # vimAlias = true; # Creates vim alias to nvim
  #   # extraPackages = with pkgs; [ ripgrep fd ]; # Make packages available to Neovim
  # };
  #

  home.packages = with pkgs;
    [
      # Your existing packages...

      # Use aider-chat from unstable channel for latest version
      unstable.neovim
    ];

  # Create writable directories for Neovim
  home.activation.createNeovimDirs = ''
    mkdir -p ${config.home.homeDirectory}/.local/state/nvim
    mkdir -p ${config.home.homeDirectory}/.local/share/nvim/{lazy,mason}
  '';

  # Manage Neovim configuration files
  home.file = {
    ".config/nvim/init.lua".source = ../../config/nvim/init.lua;
    ".config/nvim/lua" = {
      source = ../../config/nvim/lua;
      recursive = true;
    };
    # Any other Neovim config directories you need
  };

  # Ensure state directory exists for Lazy
  home.file.".local/state/nvim/.keep".text = "";
}
