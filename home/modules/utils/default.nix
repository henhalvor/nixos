{ config, pkgs, ... }: {
  home.packages = with pkgs;
    [
      # Nix tooling
      nix-search-tv
    ];

  # Nix search tv alias
  programs.zsh.shellAliases = {
    ns =
      "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
  };

  # Fuzzy finder
  programs.fzf = { enable = true; };

}
