# Yazi Float — wrapper script to launch yazi with persistent cwd
# Source: home/modules/scripts/yazi-float.nix
# Template B2: HM-only
{ self, ... }: {
  flake.nixosModules.yaziFloat = { ... }: {
    home-manager.sharedModules = [ self.homeModules.yaziFloat ];
  };

  flake.homeModules.yaziFloat = { pkgs, config, ... }: {
    home.packages = [
      (pkgs.writeShellScriptBin "yazi-float" ''
        #!${pkgs.bash}/bin/bash

        STATE_DIR="${config.home.homeDirectory}/.local/state/yazi"
        CWD_FILE="$STATE_DIR/last-cwd"

        mkdir -p "$STATE_DIR"

        if [[ -f "$CWD_FILE" ]]; then
          START_DIR="$(cat "$CWD_FILE")"
        else
          START_DIR="$HOME"
        fi

        if [[ ! -d "$START_DIR" ]]; then
          START_DIR="$HOME"
        fi

        exec ${pkgs.yazi}/bin/yazi --cwd-file="$CWD_FILE" "$START_DIR"
      '')
    ];
  };
}
