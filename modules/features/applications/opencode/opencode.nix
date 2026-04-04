# OpenCode — AI coding assistant (npm-installed, web UI service)
# Source: home/modules/applications/opencode/default.nix
# Template B2: HM-only with systemd services
{self, ...}: {
  flake.nixosModules.opencode = {...}: {
    home-manager.sharedModules = [self.homeModules.opencode];
  };

  flake.homeModules.opencode = {
    lib,
    pkgs,
    config,
    ...
  }: let
    repo = ./config;
    repoEntries = builtins.readDir repo;
    repoNames = builtins.attrNames repoEntries;
    skip = name:
      lib.elem name [
        "node_modules"
        "package.json"
        "package-lock.json"
        "bun.lockb"
        "bunfig.toml"
        ".gitignore"
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
    home.activation.seedOpencode = lib.hm.dag.entryAfter ["writeBoundary"] ''
      src="${repo}"
      dest="$HOME/.config/opencode"
      mkdir -p "$dest"

      while IFS= read -r -d "" file; do
        rel="''${file#$src/}"
        dest_file="$dest/$rel"
        if [ ! -e "$dest_file" ]; then
          echo "opencode: seeding $rel into $dest" >&2
          mkdir -p "$(dirname "$dest_file")"
          chmod u+w "$(dirname "$dest_file")"
          install -m 0644 "$file" "$dest_file"
        else
          echo "opencode: $dest_file exists; skipping" >&2
        fi
      done < <(find "$src" -type f -print0)
    '';

    # Update service
    systemd.user.services.opencode-update = {
      Unit.Description = "Update opencode (npm)";
      Service = {
        Type = "oneshot";
        ExecStart = opencodeUpdateScript;
      };
      Install.WantedBy = ["default.target"];
    };

    # Web UI service
    systemd.user.services.opencode-web = {
      Unit = {
        Description = "OpenCode Web UI";
        After = ["network.target" "opencode-update.service"];
        Requires = ["opencode-update.service"];
      };
      Service = {
        ExecStart = opencodeWebScript;
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = "%h";
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
