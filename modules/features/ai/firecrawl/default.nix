{inputs, ...}: {
  flake.nixosModules.firecrawl = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.firecrawl;
    composeArgs = [
      "--env-file"
      config.sops.templates."firecrawl-env".path
      "-f"
      "${cfg.sourceDir}/docker-compose.yaml"
      "-f"
      "${cfg.overrideFile}"
    ];
    composeArgsShell = lib.escapeShellArgs composeArgs;
  in {
    options.my.firecrawl = {
      sourceDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/firecrawl/source";
        readOnly = true;
        description = "Root-owned mutable checkout outside the dotfiles repository.";
      };

      overrideFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/firecrawl/firecrawl-override.yml";
        readOnly = true;
        description = "Installed Compose hardening override.";
      };

      repository = lib.mkOption {
        type = lib.types.str;
        default = "https://github.com/mendableai/firecrawl.git";
        description = "Firecrawl upstream Git repository.";
      };

      revision = lib.mkOption {
        type = lib.types.strMatching "[0-9a-f]{40}";
        default = "2eab3009253a56360790316fc15d1b95c0c431d2";
        description = "Auditable upstream Firecrawl revision.";
      };
    };

    config = {
      assertions = [
        {
          assertion = config.networking.hostName == "hp-server";
          message = "Firecrawl may only be enabled on hp-server.";
        }
      ];

      sops.secrets.FIRECRAWL_OPENAI_API_KEY = {
        sopsFile = ../../../../secrets/hp-agent.yaml;
        owner = "root";
        mode = "0400";
      };

      sops.templates."firecrawl-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          OPENAI_API_KEY=${config.sops.placeholder.FIRECRAWL_OPENAI_API_KEY}
        '';
      };

      systemd.tmpfiles.rules = [
        "d /var/lib/firecrawl 0700 root root -"
      ];

      systemd.services.firecrawl-bootstrap = {
        description = "Prepare pinned Firecrawl source";
        before = ["firecrawl.service"];
        after = ["network-online.target"];
        wants = ["network-online.target"];

        serviceConfig = {
          Type = "oneshot";
          User = "root";
          Group = "root";
          UMask = "0077";
        };

        path = [pkgs.coreutils pkgs.git];
        script = ''
          set -euo pipefail

          source_dir=${lib.escapeShellArg cfg.sourceDir}
          install -d -m 0700 -o root -g root /var/lib/firecrawl "$source_dir"

          if [[ ! -d "$source_dir/.git" ]]; then
            if [[ -n "$(find "$source_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
              echo "Refusing to initialize non-empty Firecrawl source directory: $source_dir" >&2
              exit 1
            fi
            git -C "$source_dir" init
            git -C "$source_dir" remote add origin ${lib.escapeShellArg cfg.repository}
          fi

          if ! git -C "$source_dir" diff --quiet --ignore-submodules -- ||
             ! git -C "$source_dir" diff --cached --quiet --ignore-submodules --; then
            echo "Refusing to replace a locally modified Firecrawl checkout." >&2
            exit 1
          fi

          git -C "$source_dir" fetch --depth 1 origin ${lib.escapeShellArg cfg.revision}
          git -C "$source_dir" checkout --detach ${lib.escapeShellArg cfg.revision}
          install -m 0400 -o root -g root \
            ${./firecrawl-compose.yml} ${lib.escapeShellArg cfg.overrideFile}

          deployed_revision=$(git -C "$source_dir" rev-parse HEAD)
          if [[ "$deployed_revision" != ${lib.escapeShellArg cfg.revision} ]]; then
            echo "Firecrawl revision mismatch: expected ${cfg.revision}, got $deployed_revision" >&2
            exit 1
          fi
          echo "Prepared Firecrawl revision $deployed_revision"
        '';
      };

      systemd.services.firecrawl = {
        description = "Pinned self-hosted Firecrawl API";
        wantedBy = ["multi-user.target"];
        requires = ["docker.service" "firecrawl-bootstrap.service"];
        after = ["docker.service" "firecrawl-bootstrap.service"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
          Group = "root";
          TimeoutStartSec = 1800;
          TimeoutStopSec = 300;
        };

        path = [pkgs.coreutils pkgs.docker pkgs.git pkgs.gnugrep];
        preStart = ''
          set -euo pipefail

          if grep -RqsE '/var/run/docker\.sock|/run/docker\.sock' \
            ${lib.escapeShellArg cfg.sourceDir}/docker-compose.yaml \
            ${lib.escapeShellArg cfg.overrideFile}; then
            echo "Refusing to start Firecrawl with the Docker socket mounted." >&2
            exit 1
          fi

          docker compose ${composeArgsShell} config --quiet
        '';
        script = ''
          revision=$(git -C ${lib.escapeShellArg cfg.sourceDir} rev-parse HEAD)
          echo "Starting Firecrawl revision $revision"
          docker compose ${composeArgsShell} up -d --remove-orphans
        '';
        preStop = ''
          docker compose ${composeArgsShell} down
        '';
      };
    };
  };
}
