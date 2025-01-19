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

  imports = [
    # Window-manager
    ./modules/window-manager/hyprland.nix

    # Applications
    ./modules/applications/zsh.nix
    ./modules/applications/${userSettings.term}.nix
    ./modules/applications/nvim.nix
    ./modules/applications/${userSettings.browser}.nix
    # ./modules/applications/microsoft-edge.nix
    ./modules/applications/yazi.nix
    ./modules/applications/aider-chat.nix
    ./modules/applications/tmux.nix
    # ./modules/applications/vivaldi.nix

    # Environment
    ./modules/environment/dev-tools.nix
    ./modules/environment/session-variables.nix

    # Settings
    ./modules/settings/git.nix
    ./modules/settings/secrets/secrets.nix
    ./modules/settings/nerd-fonts.nix
  ];


}
