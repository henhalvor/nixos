{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ]; # only include built-in oh-my-zsh plugins here
      theme = "frisk";
    };

    # Enable syntax highlighting
    syntaxHighlighting = {
      enable = true;
    };

    # Enable autosuggestions
    enableAutosuggestions = true;

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
}
