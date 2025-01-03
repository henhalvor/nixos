{ config, pkgs, ... }:

{
  home.username = "henhal";
  home.homeDirectory = "/home/henhal";
  
  # Ensure home-manager uses same pkgs instance
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Basic packages you might want
  home.packages = with pkgs; [
    git
    ripgrep
    fd
    tree
    htop
  ];

  # Git configuration
  programs.git = {
    enable = true;
    userName = "henhalvor";
    userEmail = "henhalvor@gmail.com"; # Replace with your email
    extraConfig = {
      init = {
	defaultBranch = "main";
	};
    };
  };

  # Shell configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      update = "sudo nixos-rebuild switch";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

 # SSH configuration
  programs.ssh = {
    enable = true;
    matchBlocks = {
      # This configures GitHub specifically
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

 # Install neovim
  programs.neovim.enable = true;

  # Manage existing dotfiles
  home.file.".config/nvim" = {
    source = ./config/nvim;  # This path should point to your nvim config directory
    recursive = true;        # Include all subdirectories
  };
}
