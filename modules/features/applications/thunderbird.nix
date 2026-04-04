{self, ...}: {
  flake.nixosModules.thunderbird = {...}: {
    home-manager.sharedModules = [self.homeModules.thunderbird];
  };
  flake.homeModules.thunderbird = {lib, config, pkgs, ...}: let
    toggleThunderbird = pkgs.writeShellScriptBin "toggle-thunderbird" ''
      if ! pgrep -fa '(^|/)(thunderbird|thunderbird-bin)( |$)' >/dev/null; then
        setsid -f ${lib.getExe config.programs.thunderbird.package}
        sleep 1
      fi

      if [ -n "''${NIRI_SOCKET-}" ] || [ "''${XDG_CURRENT_DESKTOP-}" = "niri" ]; then
        niri msg action focus-workspace mail
      elif [ -n "''${HYPRLAND_INSTANCE_SIGNATURE-}" ] || [ "''${XDG_CURRENT_DESKTOP-}" = "Hyprland" ]; then
        hyprctl dispatch togglespecialworkspace mail
      fi
    '';
  in {
    programs.thunderbird.enable = true;
    programs.thunderbird.profiles.default = {
      isDefault = true;
    };

    home.packages = [toggleThunderbird];
  };
}
