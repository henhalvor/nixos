{ config, lib, pkgs, ... }:
{
  programs.hyprlock = {
    enable = true;
    # Stylix already configures hyprlock, we just enable it here
    # Additional customization can be added with lib.mkForce if needed
  };
}
