{ config, lib, pkgs, ... }:
let
  desktopLib = import ../lib.nix { inherit lib pkgs; };
in {
  home.packages = with pkgs; [
    wl-clipboard
    cliphist
    # Real command wrappers
    (pkgs.writeShellScriptBin "clipboard-history" ''
      ${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi-wayland}/bin/rofi -dmenu -theme ${config.home.homeDirectory}/.config/rofi/theme.rasi | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
    '')
    (pkgs.writeShellScriptBin "clipboard-clear" ''
      ${pkgs.cliphist}/bin/cliphist wipe
    '')
  ];

  # Systemd service (text + image support)
  systemd.user.services.cliphist = desktopLib.mkWlPasteWatchService {
    name = "cliphist";
    description = "Cliphist clipboard manager";
    command = "${pkgs.cliphist}/bin/cliphist store";
    types = [ "text" "image" ];
  };
}
