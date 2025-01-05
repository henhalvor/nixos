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

    # Wayland essentials
    wofi            # Application launcher
    waybar          # Status bar
    swaync          # Notification daemon
    swaylock        # Screen locker
    swayidle        # Idle management daemon
    wl-clipboard    # Clipboard manager
    grim            # Screenshot utility
    slurp           # Screen region selector
    wf-recorder     # Screen recording
    brightnessctl   # Brightness control

    # Terminal
    unstable.ghostty
    
    # Core development tools
    git
    lazygit
    lazydocker
    ripgrep
    tree-sitter
    unzip
    
    # Node.js ecosystem
    nodejs_20
    nodePackages.npm
    
    # Rust ecosystem
    rustc
    cargo
    
    # Python ecosystem
    python311
    python311Packages.pip
    
    # Go ecosystem
    go
    
    # Build tools and utilities
    gcc
    gnumake
    cmake
  ];

  # Ensure npm config directory exists
  home.activation = {
    createDevDirectories = ''
      mkdir -p ${config.home.homeDirectory}/.local/dev/{npm/{global,cache,config},cargo,rustup,python,go}
      mkdir -p ${config.home.homeDirectory}/.local/share/nvim/{lazy,mason}
    '';
  };



 # Configure all package managers to use our organized directory structure
  home.sessionVariables = {
    # Base directory for all development tools
    DEV_HOME = "$HOME/.local/dev";
    
    # Tool-specific home directories
    NPM_HOME = "$HOME/.local/dev/npm";
    NPM_CONFIG_PREFIX = "$HOME/.local/dev/npm/global";
    CARGO_HOME = "$HOME/.local/dev/cargo";
    RUSTUP_HOME = "$HOME/.local/dev/rustup";
    PYTHONUSERBASE = "$HOME/.local/dev/python";
    GOPATH = "$HOME/.local/dev/go";

    # Combine all PATH additions in a single definition
    PATH = builtins.concatStringsSep ":" [
      "$HOME/.local/dev/npm/global/bin"
      "$HOME/.local/dev/cargo/bin"
      "$HOME/.local/dev/python/bin"
      "$HOME/.local/dev/go/bin"
      "$PATH"
    ];
  };


  # Configure npm to use our directory structure
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.local/dev/npm/global
    cache=${config.home.homeDirectory}/.local/dev/npm/cache
    init-module=${config.home.homeDirectory}/.local/dev/npm/config/npm-init.js
  '';

  # Configure pip to use our directory structure
  home.file.".config/pip/pip.conf".text = ''
    [global]
    user = true
    prefix = ${config.home.homeDirectory}/.local/dev/python
  '';

 #
 # Neovim configuration
 #
  programs.neovim.enable = true;

  # Create writable directories for Neovim
  home.activation.createNeovimDirs = ''
    mkdir -p ${config.home.homeDirectory}/.local/state/nvim
    mkdir -p ${config.home.homeDirectory}/.local/share/nvim/{lazy,mason}
  '';

  # Manage Neovim configuration files
  home.file = {
    ".config/nvim/init.lua".source = ./config/nvim/init.lua;
    ".config/nvim/lua" = {
      source = ./config/nvim/lua;
      recursive = true;
    };
    # Any other Neovim config directories you need
  };

  # Ensure state directory exists for Lazy
  home.file.".local/state/nvim/.keep".text = "";

 #
 #
 #

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


  # Import Hyprland configuration
  imports = [ ./hyprland.nix ];

  # Shell configuration
 programs.zsh = {
  enable = true;
  autosuggestion.enable = true;
  oh-my-zsh = {
    enable = true;
    plugins = [ "git" ];
    theme = "frisk";
  };
  syntaxHighlighting.enable = true;
 initExtra = ''
    # Load secrets
    if [ -f "$HOME/.dotfiles/home/secrets/load-secrets.sh" ]; then
      source "$HOME/.dotfiles/home/secrets/load-secrets.sh"
    fi
  '';
   history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      save = 10000;
      ignoreDups = true;
      share = true;
    };
  };

   # Create the secrets directory and scripts
home.file = {
  ".local/secrets/load-secrets.sh" = {
    source = ./secrets/load-secrets.sh;  # This is relative to home.nix location
    executable = true;
  };
};


 # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
