{
  config,
  pkgs,
  userSettings,
  unstable,
  ...
}: {
  home.username = userSettings.username;
  home.homeDirectory = userSettings.homeDirectory;
  home.stateVersion = "24.05";

  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

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

    # Scripts
    ../../home/modules/scripts/search-with-zoxide.nix

    # Utils
    ../../home/modules/utils/default.nix
  ];
}
