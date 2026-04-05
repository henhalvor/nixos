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
    osConfig,
    ...
  }: let
    isWorkstation = osConfig.networking.hostName == "workstation";
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

    opencodeWebScript = port: pkgs.writeShellScript "opencode-web-${toString port}" ''
      export PATH=$HOME/.npm-global/bin:$PATH
      export OPENCODE_SERVER_PASSWORD=password123
      export OPENCODE_SERVER_USERNAME=henhal
      exec opencode web --hostname 0.0.0.0 --port ${toString port}
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

    mkWebService = {
      description,
      port,
      workingDirectory,
    }: {
      Unit = {
        inherit description;
        After = ["network.target" "opencode-update.service"];
        Requires = ["opencode-update.service"];
      };
      Service = {
        ExecStart = opencodeWebScript port;
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = workingDirectory;
      };
      Install.WantedBy = ["default.target"];
    };
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

    systemd.user.services = {
      opencode-update = {
        Unit.Description = "Update opencode (npm)";
        Service = {
          Type = "oneshot";
          ExecStart = opencodeUpdateScript;
        };
        Install.WantedBy = ["default.target"];
      };
    }
    // lib.optionalAttrs isWorkstation {
      opencode-web = mkWebService {
        description = "OpenCode Web UI";
        port = 4096;
        workingDirectory = "%h";
      };

      opencode-vault-web = mkWebService {
        description = "OpenCode Vault Web UI";
        port = 4097;
        workingDirectory = "%h/vault";
      };
    };
  };
}
