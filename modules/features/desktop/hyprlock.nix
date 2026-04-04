# Hyprlock — Hyprland lock screen
# Source: home/modules/desktop/lock/hyprlock.nix
# Template B2: HM-only (Stylix handles theming)
{self, ...}: {
  flake.nixosModules.hyprlock = {...}: {
    home-manager.sharedModules = [self.homeModules.hyprlock];
  };

  flake.homeModules.hyprlock = {...}: {
    programs.hyprlock.enable = true;
  };
}
