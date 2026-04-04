# Utils — CLI utilities (bat, fd, btop, ripgrep, fzf, nix-search-tv)
# Source: home/modules/utils/default.nix
{ self, ... }: {
  flake.nixosModules.utils = { ... }: {
    home-manager.sharedModules = [ self.homeModules.utils ];
  };

  flake.homeModules.utils = { pkgs, ... }: {
    home.packages = with pkgs; [
      nix-search-tv
      bat
      fd
      tree
      btop
      ripgrep
    ];

    programs.zsh.shellAliases = {
      ns = "nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history";
    };

    programs.fzf.enable = true;
  };
}
