# Nerd Fonts — Hack font
# Source: home/modules/settings/nerd-fonts.nix
{ self, ... }: {
  flake.nixosModules.nerdFonts = { ... }: {
    home-manager.sharedModules = [ self.homeModules.nerdFonts ];
  };
  flake.homeModules.nerdFonts = { pkgs, ... }: {
    home.packages = with pkgs; [ nerd-fonts.hack ];
  };
}
