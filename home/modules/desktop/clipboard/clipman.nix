{ config, lib, pkgs, ... }:
let
  desktopLib = import ../lib.nix { inherit lib pkgs; };
in {
  home.packages = with pkgs; [
    wl-clipboard
    clipman
    # Real command wrappers that work everywhere (systemd, compositor keybinds, all shells)
    (pkgs.writeShellScriptBin "clipboard-history" ''
      ${pkgs.clipman}/bin/clipman pick -t rofi -T'-theme ${config.home.homeDirectory}/.config/rofi/theme.rasi'
    '')
    (pkgs.writeShellScriptBin "clipboard-clear" ''
      ${pkgs.clipman}/bin/clipman clear --all
    '')
  ];

  # Systemd service (text only - images disabled to prevent JSON corruption)
  systemd.user.services.clipman = desktopLib.mkWlPasteWatchService {
    name = "clipman";
    description = "Clipman clipboard manager";
    command = "${pkgs.clipman}/bin/clipman store";
    types = [ "text" ];
  };
}
