{ config, pkgs, userSettings, ... }:

{
  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";

  # Ensure home-manager uses same pkgs instance
  home.stateVersion = "24.11";
  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  ### Imports

  # Window-manager
  # imports = [ ./modules/window-manager/hyprland.nix ];

  # Applications
  imports = [ ./modules/applications/zsh.nix ];
  imports = [ ./modules/applications/kitty.nix ];
  imports = [ ./modules/applications/nvim.nix ];

  # Environment
  imports = [ ./modules/environment/dev-tools.nix ];
  imports = [ ./modules/environment/session-variables.nix ];

  # Settings
  imports = [ ./modules/settings/git.nix ];
  imports = [ ./modules/settings/secrets/secrets.nix ];


}
