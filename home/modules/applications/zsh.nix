{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
    };
    shellAliases = {
      v = "nvim";
    };
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    initExtra = ''
      # First source the theme
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      # Then source your configuration
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
    '';
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      save = 10000;
      ignoreDups = true;
      share = true;
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Link your p10k config file
  home.file.".p10k.zsh" = {
    source = ../../config/.p10k.zsh;
    onChange = ''
      # This ensures the config is reloaded when the file changes
      if [[ -n "$ZDOTDIR" ]]; then
        zsh_path="$ZDOTDIR/.zshrc"
      else
        zsh_path="$HOME/.zshrc"
      fi
      if [[ -f "$zsh_path" ]]; then
        source "$zsh_path"
      fi
    '';
  };
}


