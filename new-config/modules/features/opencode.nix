# OpenCode — AI coding assistant (npm-installed, web UI service)
# Source: home/modules/applications/opencode/default.nix
# Template B2: HM-only with systemd services
{ self, ... }: {
  flake.nixosModules.opencode = { ... }: {
    home-manager.sharedModules = [ self.homeModules.opencode ];
  };

  flake.homeModules.opencode = { lib, pkgs, config, ... }: let
    repo = ./opencode-config;
    repoEntries = builtins.readDir repo;
    repoNames = builtins.attrNames repoEntries;
    skip = name: lib.elem name [
      "node_modules" "package.json" "package-lock.json"
      "bun.lockb" "bunfig.toml" ".gitignore"
    ];
    want = lib.filter (n: !(skip n)) repoNames;
    namesStr = lib.concatStringsSep " " want;

    opencodeWebScript = pkgs.writeShellScript "opencode-web" ''
      export PATH=$HOME/.npm-global/bin:$PATH
      export OPENCODE_SERVER_PASSWORD=password123
      export OPENCODE_SERVER_USERNAME=henhal
      exec opencode web --mdns --port 4096
    '';

    opencodeUpdateScript = pkgs.writeShellScript "opencode-update" ''
      export PATH=$HOME/.npm-global/bin:$PATH
      current=$(opencode --version 2>/dev/null || echo none)
      latest=$(npm view opencode version)
      if [ "$current" != "$latest" ]; then
        echo "Updating opencode $current -> $latest"
        npm install -g opencode-ai@latest
      else
        echo "opencode already up to date ($current)"
      fi
    '';
  in {
    # Seed config files on first activation
    home.activation.seedOpencode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
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

    # Update service
    systemd.user.services.opencode-update = {
      Unit.Description = "Update opencode (npm)";
      Service = {
        Type = "oneshot";
        ExecStart = opencodeUpdateScript;
      };
      Install.WantedBy = [ "default.target" ];
    };

    # Web UI service
    systemd.user.services.opencode-web = {
      Unit = {
        Description = "OpenCode Web UI";
        After = [ "network.target" "opencode-update.service" ];
        Requires = [ "opencode-update.service" ];
      };
      Service = {
        ExecStart = opencodeWebScript;
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = "%h";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
