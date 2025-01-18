{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ]; # only include built-in oh-my-zsh plugins here
    };

     # Add your aliases here
    shellAliases = {
      v = "nvim";
      # You can add more aliases here, for example:
      # ll = "ls -la";
      # ga = "git add";
      # gc = "git commit";
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

  # Enable zoxide
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };


  # Link your p10k config file
  home.file.".p10k.zsh".source = ../../config/.p10k.zsh; # Assuming p10k.zsh is in the same directory as zsh.nix
}
