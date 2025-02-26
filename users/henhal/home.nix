{ config, pkgs, userSettings, ... }:

{
  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";

  # Ensure home-manager uses same pkgs instance
  home.stateVersion = userSettings.stateVersion;
  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  ### Imports

  imports = [
    # Window-manager
    ../../home/modules/window-manager/hyprland.nix

    # Applications
    ../../home/modules/applications/zsh.nix
    ../../home/modules/applications/${userSettings.term}.nix
    ../../home/modules/applications/nvim.nix
    ../../home/modules/applications/${userSettings.browser}.nix
    ../../home/modules/applications/yazi.nix
    ../../home/modules/applications/aider-chat.nix
    ../../home/modules/applications/tmux.nix
    ../../home/modules/applications/vial.nix

    # Environment
    ../../home/modules/environment/dev-tools.nix
    ../../home/modules/environment/session-variables.nix
    ../../home/modules/environment/direnv.nix

    # Settings
    ../../home/modules/settings/git.nix
    ../../home/modules/settings/secrets/secrets.nix
    ../../home/modules/settings/nerd-fonts.nix
    ../../home/modules/settings/ssh.nix
  ];


}
