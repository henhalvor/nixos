{
  config,
  pkgs,
  hostConfig,
  unstable,
  ...
}: let
  toggleMonitorsWorkstation = import ../../scripts/toggle-monitors-workstation-niri.nix {
    inherit pkgs;
  };
  brightnessExternal = import ../../scripts/brightness-external.nix {
    inherit pkgs;
  };
  hostPackages =
    if hostConfig.hostname == "workstation"
    then [
      toggleMonitorsWorkstation
      brightnessExternal
    ]
    else [];
  hostConfigFile =
    if hostConfig.hostname == "workstation"
    then "hosts/workstation.kdl"
    else "hosts/default.kdl";
  niriConfigDir = "${config.home.homeDirectory}/.dotfiles/home/modules/desktop/sessions/niri-config";
in {
  imports = [../launchers/rofi.nix];

  home.packages = with pkgs;
    [
      brightnessctl
      pamixer
      playerctl
      ddcutil
      bluez
      blueberry
      swaybg
      xwayland-satellite
    ]
    ++ hostPackages;

  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "niri";
    XKB_DEFAULT_OPTIONS = "caps:escape";
    SDL_VIDEODRIVER = "wayland";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    GDK_BACKEND = "wayland";
  };

  xdg.configFile = {
    "niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/config.kdl";
    "niri/common".source = config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/common";
    "niri/host.kdl".source = config.lib.file.mkOutOfStoreSymlink "${niriConfigDir}/${hostConfigFile}";
  };
}
