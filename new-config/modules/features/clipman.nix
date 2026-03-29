# Clipman — clipboard manager (Wayland)
# Source: home/modules/desktop/clipboard/clipman.nix + home/modules/desktop/lib.nix
# Template B2: HM-only with inline wl-paste watcher service
{self, ...}: {
  flake.nixosModules.clipman = {...}: {
    home-manager.sharedModules = [self.homeModules.clipman];
  };

  flake.homeModules.clipman = {config, pkgs, lib, ...}: {
    home.packages = with pkgs; [
      wl-clipboard
      clipman
      (pkgs.writeShellScriptBin "clipboard-history" ''
        ${pkgs.clipman}/bin/clipman pick -t rofi -T'-theme ${config.home.homeDirectory}/.config/rofi/theme.rasi'
      '')
      (pkgs.writeShellScriptBin "clipboard-clear" ''
        ${pkgs.clipman}/bin/clipman clear --all
      '')
    ];

    # Systemd user service (text only — images disabled to prevent JSON corruption)
    systemd.user.services.clipman = {
      Unit = {
        Description = "Clipman clipboard manager";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.clipman}/bin/clipman store";
        Restart = "on-failure";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
