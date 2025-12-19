{
  config,
  pkgs,
  lib,
  userSettings,
  unstable,
  ...
}: {
  home.username = userSettings.username;
  home.homeDirectory = userSettings.homeDirectory;
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;

  # Termux configuration - Copy termux.properties (can't be symlinked)
  # Termux doesn't follow symlinks, so we need to copy the file
  home.activation.termuxConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.termux/
    $DRY_RUN_CMD cp -f ${../../nix-on-droid/termux.properties} ~/.termux/termux.properties
  '';

  # Core packages
  home.packages = with pkgs; [
    vim
  ];

  imports = [
    # CLI Applications
    ../../home/modules/applications/zsh.nix
    ../../home/modules/applications/tmux.nix
    ../../home/modules/applications/yazi.nix
    ../../home/modules/applications/nvf.nix

    # Environment
    ../../home/modules/environment/dev-tools.nix
    ../../home/modules/environment/session-variables.nix
    ../../home/modules/environment/direnv.nix

    # utils
    ../../home/modules/utils/default.nix

    # Settings
    ../../home/modules/settings/git.nix
    ../../home/modules/settings/nerd-fonts.nix
    # Skip: ssh.nix (uses home.activation - test later)
    # Skip: secrets.nix (per user request)
    # Skip: udiskie.nix (GUI daemon)
    # Skip: stylix (desktop-only - terminal colors configured in nix-on-droid/theme.nix)

    # Scripts
    ../../home/modules/scripts/search-with-zoxide.nix
  ];
}
