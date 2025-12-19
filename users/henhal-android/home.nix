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

  # Session variables - Set hostname for zsh prompt
  home.sessionVariables = {
    HOSTNAME = "galaxy-tab-s10-ultra";
  };

  # Font configuration for terminal applications
  fonts.fontconfig.enable = true;

  # Termux configuration - Copy termux.properties (can't be symlinked)
  # Termux doesn't follow symlinks, so we need to copy the file
  home.activation.termuxConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ~/.termux/
    $DRY_RUN_CMD cp -f ${../../nix-on-droid/termux.properties} ~/.termux/termux.properties
  '';

  # Copy all Nerd Font files so terminal can find all glyphs
  home.activation.copyNerdFonts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $VERBOSE_ECHO "Copying Nerd Fonts to ~/.termux/fonts/"
    $DRY_RUN_CMD mkdir -p ~/.termux/fonts/
    $DRY_RUN_CMD cp -f ${pkgs.nerd-fonts.hack}/share/fonts/truetype/NerdFonts/Hack/*.ttf ~/.termux/fonts/
  '';

  # Ensure HOSTNAME is set in shell profile and override system hostname
  home.file.".zshenv".text = ''
    # Set hostname for zsh prompt
    export HOSTNAME="galaxy-tab-s10-ultra"
    
    # Override hostname command for powerlevel10k
    # On Android, hostname returns "localhost", so we override it
    function hostname() {
      echo "galaxy-tab-s10-ultra"
    }
  '';

  # Use Android-specific p10k config (with hardcoded hostname)
  home.file.".p10k.zsh".source = lib.mkForce ../../nix-on-droid/.p10k-android.zsh;

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

    # Android/Termux-specific
    ../../nix-on-droid/modules/basic-cli-tools.nix

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
