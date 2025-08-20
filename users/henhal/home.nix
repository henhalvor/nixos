{ config, pkgs, windowManager, userSettings, stylix, unstable, ... }: {
  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";

  # Ensure home-manager uses same pkgs instance
  home.stateVersion = userSettings.stateVersion;
  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  ### Imports

  # home.packages = with pkgs; [ unstable.ankiAddons unstable.anki ];

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
      # Add this line to import the Stylix Home Manager module
      stylix.homeModules.stylix

      # Applications
      ../../home/modules/applications/zsh.nix
      ../../home/modules/applications/${userSettings.term}.nix
      ../../home/modules/applications/${userSettings.browser}.nix
      ../../home/modules/applications/yazi.nix
      ../../home/modules/applications/aider-chat.nix
      # ../../home/modules/applications/claude-code.nix # installed via npm
      ../../home/modules/applications/tmux.nix
      ../../home/modules/applications/vial.nix
      ../../home/modules/applications/brave.nix
      ../../home/modules/applications/vscode.nix
      ../../home/modules/applications/cursor.nix
      ../../home/modules/applications/mission-center.nix
      # ../../home/modules/applications/google-chrome.nix
      ../../home/modules/applications/gimp.nix
      ../../home/modules/applications/microsoft-edge.nix
      ../../home/modules/applications/nvim.nix
      ../../home/modules/applications/nautilus.nix
      ../../home/modules/applications/spotify.nix
      ../../home/modules/applications/nsxiv.nix
      ../../home/modules/applications/zathura.nix
      ../../home/modules/applications/mpv.nix
      ../../home/modules/applications/libreoffice.nix
      # ../../home/modules/applications/nvf.nix

      # Environment
      ../../home/modules/environment/dev-tools.nix
      ../../home/modules/environment/session-variables.nix
      ../../home/modules/environment/direnv.nix

      # Settings
      ../../home/modules/settings/git.nix
      ../../home/modules/settings/secrets/secrets.nix
      ../../home/modules/settings/nerd-fonts.nix
      ../../home/modules/settings/ssh.nix
      ../../home/modules/settings/udiskie.nix

      # Theming
      # ../../home/modules/themes/catppuccin/default.nix
      ../../home/modules/themes/stylix/default.nix

      # Scripts
      ../../home/modules/scripts/power-monitor.nix

    ];
}
