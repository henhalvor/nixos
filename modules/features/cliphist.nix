# Cliphist — clipboard manager (Wayland, with image support)
# Source: home/modules/desktop/clipboard/cliphist.nix + home/modules/desktop/lib.nix
# Template B2: HM-only with inline wl-paste watcher service
{self, ...}: {
  flake.nixosModules.cliphist = {...}: {
    home-manager.sharedModules = [self.homeModules.cliphist];
  };

  flake.homeModules.cliphist = {config, pkgs, lib, ...}: let
    watchScript = pkgs.writeShellScript "cliphist-watch" ''
      ${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store &
      ${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store &
      wait
    '';
  in {
    home.packages = with pkgs; [
      wl-clipboard
      cliphist
      (pkgs.writeShellScriptBin "clipboard-history" ''
        ${pkgs.cliphist}/bin/cliphist list | ${pkgs.rofi}/bin/rofi -dmenu -theme ${config.home.homeDirectory}/.config/rofi/theme.rasi | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
      '')
      (pkgs.writeShellScriptBin "clipboard-clear" ''
        ${pkgs.cliphist}/bin/cliphist wipe
      '')
    ];

    systemd.user.services.cliphist = {
      Unit = {
        Description = "Cliphist clipboard manager";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${watchScript}";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
