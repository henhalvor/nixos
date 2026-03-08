{
  config,
  lib,
  pkgs,
  ...
}: {
  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  programs.dconf.enable = true;

  fonts.packages = with pkgs; [noto-fonts noto-fonts-color-emoji];
}
