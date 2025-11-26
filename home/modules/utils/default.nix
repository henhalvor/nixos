{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Nix tooling
    nix-search-tv
    bat # Improved cat replacement
    fd # Simple, fast and user-friendly alternative to find
    tree # Display directories as trees
    btop
  ];

  # Nix search tv alias
  programs.zsh.shellAliases = {
    ns = "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
  };

  # Fuzzy finder
  programs.fzf = {enable = true;};
}
