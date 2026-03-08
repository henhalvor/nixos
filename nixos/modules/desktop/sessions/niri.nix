{ userSettings, unstable, ... }: {
  programs.niri = {
    enable = true;
    package = unstable.niri;
  };

  security.pam.services.swaylock = {};
  security.polkit.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    XDG_SESSION_TYPE = "wayland";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    GDK_BACKEND = "wayland";
    XDG_CURRENT_DESKTOP = "niri";
  };

  users.users.${userSettings.username}.extraGroups = [ "video" ];
  programs.light.enable = true;
}
