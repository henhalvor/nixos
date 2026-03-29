{
  pkgs,
  config,
  ...
}: {
  # ...existing module options...

  home.packages = [
    (pkgs.writeShellScriptBin "yazi-float" ''
      #!${pkgs.bash}/bin/bash

      STATE_DIR="${config.home.homeDirectory}/.local/state/yazi"
      CWD_FILE="$STATE_DIR/last-cwd"

      mkdir -p "$STATE_DIR"

      # If we have a saved cwd, start there, otherwise use $HOME
      if [[ -f "$CWD_FILE" ]]; then
        START_DIR="$(cat "$CWD_FILE")"
      else
        START_DIR="$HOME"
      fi

      # Safety: if folder no longer exists
      if [[ ! -d "$START_DIR" ]]; then
        START_DIR="$HOME"
      fi

      exec ${pkgs.yazi}/bin/yazi --cwd-file="$CWD_FILE" "$START_DIR"
    '')
  ];
}
