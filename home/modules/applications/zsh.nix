{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ]; # only include built-in oh-my-zsh plugins here
      theme = "frisk";
    };

    # Enable syntax highlighting via the nix package
    syntaxHighlighting = {
      enable = true;
      package = pkgs.zsh-syntax-highlighting;
    };

    # Enable autosuggestions via the nix package
    enableAutosuggestions = true;
    autosuggestions.package = pkgs.zsh-autosuggestions;

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
