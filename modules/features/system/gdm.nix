# GDM — GNOME Display Manager
# Source: nixos/modules/desktop/display-managers/gdm.nix
{...}: {
  flake.nixosModules.gdm = {...}: {
    services.xserver.displayManager.gdm = {
      enable = true;
      wayland = true;
    };
  };
}
