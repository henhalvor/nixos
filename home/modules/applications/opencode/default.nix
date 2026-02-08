{ lib, pkgs, config, ... }:

let
  cfg = config.modules.applications.opencode;
in {
  options = {
    modules.applications.opencode = {
      enable = lib.mkEnableOption "Manage ~/.config/opencode from repo";

      npmInstall = {
        enable = lib.mkOption { type = lib.types.bool; default = false; };
        package = lib.mkOption { type = lib.types.str; default = "opencode-ai@latest"; };
        nodePackage = lib.mkOption { type = lib.types.package; default = pkgs.nodejs; };
        markerFile = lib.mkOption { type = lib.types.str; default = "${config.xdg.stateHome}/opencode/npm-opencode-ai.version"; };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Link the whole opencode tree from the module directory into ~/.config/opencode
    xdg.configFile."opencode" = {
      source = ./opencode;
      recursive = true;
    };

    # Optionally provide node for running npm in activation
    home.packages = lib.optional cfg.npmInstall.enable cfg.npmInstall.nodePackage;

    # Optional activation hook to install/update opencode-ai globally via npm.
    # This is guarded by cfg.npmInstall.enable and writes a marker to avoid
    # reinstalling on every switch.
    home.activation.installOpencodeNpm = lib.mkIf cfg.npmInstall.enable
      (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        set -eu

        npm="${cfg.npmInstall.nodePackage}/bin/npm"
        marker="${cfg.npmInstall.markerFile}"
        mkdir -p "$(dirname "$marker")"

        # Try to resolve latest version (best-effort); if offline, desired may be empty
        desired="$($npm view opencode-ai version 2>/dev/null || true)"

        if [ -f "$marker" ] && [ -n "$desired" ] && [ "$(cat "$marker")" = "$desired" ]; then
          exit 0
        fi

        if [ -z "$desired" ]; then
          # cannot resolve latest; if marker exists assume installed, otherwise attempt install once
          if [ -f "$marker" ]; then
            exit 0
          fi
          echo "opencode: unable to resolve latest version; installing ${cfg.npmInstall.package} once" >&2
          $DRY_RUN_CMD $npm i -g "${cfg.npmInstall.package}"
          printf '%s' "manual" > "$marker"
          exit 0
        fi

        echo "opencode: installing/updating opencode-ai to $desired" >&2
        $DRY_RUN_CMD $npm i -g "opencode-ai@$desired"
        $DRY_RUN_CMD printf '%s' "$desired" > "$marker"
      '');
  };
}
