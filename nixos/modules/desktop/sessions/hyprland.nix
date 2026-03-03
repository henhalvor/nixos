{ config, lib, pkgs, userSettings, ... }:
let
  # Override the Hyprland desktop session file to use start-hyprland wrapper
  hyprlandSession = (pkgs.writeTextDir "share/wayland-sessions/hyprland.desktop" ''
    [Desktop Entry]
    Name=Hyprland
    Comment=An intelligent dynamic tiling Wayland compositor
    Exec=start-hyprland
    Type=Application
    DesktopNames=Hyprland
    Keywords=tiling;wayland;compositor;
  '').overrideAttrs { passthru.providedSessions = [ "hyprland" ]; };
in
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

  security.pam.services.hyprlock = {};

  services.displayManager.sessionPackages = [ hyprlandSession ];

  # Wayland session variables
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    GDK_BACKEND = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
  };

  # Allow user to control brightness and volume
  users.users.${userSettings.username}.extraGroups = [ "video" ];
  programs.light.enable = true;
}
