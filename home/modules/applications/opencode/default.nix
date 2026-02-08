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
    # Instead of symlinking files from the Nix store (which would be
    # immutable), seed the user's ~/.config/opencode directory from the
    # repo on first activation only. This lets OpenCode write and update
    # files (node_modules, runtime files) under ~/.config/opencode freely.

    let
      repo = ./opencode;
      repoEntries = builtins.readDir repo; # name -> type
      repoNames = builtins.attrNames repoEntries;
      skip = name: lib.elem name [ "node_modules" "package.json" "package-lock.json" "bun.lockb" "bunfig.toml" ".gitignore" ];
      want = lib.filter (n: ! (skip n)) repoNames;
      namesStr = lib.concatStringsSep " " want;
    in

    # Activation: create ~/.config/opencode if missing and copy repo children
    # into it only if target doesn't already exist. That preserves any
    # runtime-installed node_modules or local edits and avoids making the
    # files read-only in /nix/store.
    home.activation.seedOpencode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      src="${repo}"
      dest="$HOME/.config/opencode"
      mkdir -p "$dest"

      for name in ${namesStr}; do
        if [ ! -e "$dest/$name" ]; then
          echo "opencode: seeding $name into $dest" >&2
          if [ -d "$src/$name" ]; then
            $DRY_RUN_CMD cp -a "$src/$name" "$dest/"
          else
            $DRY_RUN_CMD install -m 0644 "$src/$name" "$dest/$name"
          fi
        else
          echo "opencode: $dest/$name exists; skipping" >&2
        fi
      done
    '';

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
