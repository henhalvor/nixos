{ config, pkgs, windowManager, userSettings, ... }:

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

  imports =
    # Window manager (conditional import)
    (if windowManager == "hyprland" then
      [ ../../home/modules/window-manager/hyprland.nix ]
    else if windowManager == "sway" then
      [ ../../home/modules/window-manager/sway.nix ]
    else if windowManager == "gnome" then
    # Need to add gnome specific home config
      [ ]
    else if windowManager == "none" then
      [ ]
    else [
      throw
      "Unsupported window manager in flake's windowManager: ${windowManager}"
    ]) ++ [
      # Applications
      ../../home/modules/applications/zsh.nix
      ../../home/modules/applications/nvim.nix
      ../../home/modules/applications/yazi.nix
      ../../home/modules/applications/aider-chat.nix
      ../../home/modules/applications/claude-code.nix
      ../../home/modules/applications/tmux.nix
      ../../home/modules/applications/kitty.nix
      # Environment
      ../../home/modules/environment/dev-tools.nix
      ../../home/modules/environment/session-variables.nix
      ../../home/modules/environment/direnv.nix

      # Settings
      ../../home/modules/settings/git.nix
      ../../home/modules/settings/secrets/secrets.nix
      ../../home/modules/settings/nerd-fonts.nix
      ../../home/modules/settings/ssh.nix
      ../../home/modules/settings/theme.nix
    ];

}
