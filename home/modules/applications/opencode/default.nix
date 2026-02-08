{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.modules.applications.opencode;

  repo = ./opencode;
  repoEntries = builtins.readDir repo;
  repoNames = builtins.attrNames repoEntries;
  skip = name: lib.elem name ["node_modules" "package.json" "package-lock.json" "bun.lockb" "bunfig.toml" ".gitignore"];
  want = lib.filter (n: ! (skip n)) repoNames;
  namesStr = lib.concatStringsSep " " want;
in {
  config = {
    home.activation.seedOpencode = lib.hm.dag.entryAfter ["writeBoundary"] ''
      src="${repo}"
      dest="$HOME/.config/opencode"
      mkdir -p "$dest"

      for name in ${namesStr}; do
        if [ ! -e "$dest/$name" ]; then
          echo "opencode: seeding $name into $dest" >&2
          if [ -d "$src/$name" ]; then
            cp -a "$src/$name" "$dest/"
          else
            install -m 0644 "$src/$name" "$dest/$name"
          fi
        else
          echo "opencode: $dest/$name exists; skipping" >&2
        fi
      done
    '';
  };
}
