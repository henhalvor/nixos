{ config, pkgs, ... }:

{

  # Shell configuration
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "zsh-autosuggestions"
        "zsh-syntax-highlighting"
      ];
      theme = "frisk"; # You can also specify your custom theme or another built-in one.
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

  # Install zsh plugins
  home.packages = with pkgs; [
    zsh-syntax-highlighting
    zsh-autosuggestions
  ];


}
