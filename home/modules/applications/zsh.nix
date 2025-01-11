{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ]; # only include built-in oh-my-zsh plugins here
    };

    # Enable syntax highlighting
    syntaxHighlighting = {
      enable = true;
    };

    # Enable autosuggestions
    autosuggestion.enable = true;

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];



    initExtra = ''
      # Load secrets
      if [ -f "$HOME/.dotfiles/home/secrets/load-secrets.sh" ]; then
        source "$HOME/.dotfiles/home/secrets/load-secrets.sh"
      fi

      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';

    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      save = 10000;
      ignoreDups = true;
      share = true;
    };
  };


  # Link your p10k config file
  home.file.".p10k.zsh".source = ../../config/p10k.zsh; # Assuming p10k.zsh is in the same directory as zsh.nix
}
