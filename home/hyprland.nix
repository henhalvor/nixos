{ config, pkgs, ... }:

{
  home.sessionVariables = {
    # Wayland specific
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    settings = {
     general = {
        "$mod" = "SUPER";
      };
      bindm = [
        "$mod, Return, kitty"
      ];
      input = {
        "kb_layout" = "no";
      };
    };
  };
}
