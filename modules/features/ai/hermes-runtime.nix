{inputs, ...}: {
  flake.nixosModules.hermesRuntime = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.hermesRuntime;
    runtimePath = lib.makeBinPath [
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.curl
      pkgs.fd
      pkgs.git
      pkgs.nix
      pkgs.nodejs_22
      pkgs.ripgrep
    ];
    maintenance = pkgs.writeShellApplication {
      name = "hermes-agent-maintenance";
      runtimeInputs = [pkgs.bashInteractive pkgs.coreutils pkgs.sudo];
      text = ''
        if [[ $EUID -ne 0 ]]; then
          echo "Run this command through sudo." >&2
          exit 1
        fi

        if [[ $# -eq 0 ]]; then
          set -- ${pkgs.bashInteractive}/bin/bash --noprofile --norc
        fi

        exec sudo -u ${cfg.user} -H env \
          HOME=${cfg.stateDir} \
          PATH=${cfg.executableDir}:${runtimePath} \
          HERMES_ENV_FILE=${config.sops.templates."hermes-agent-env".path} \
          ${pkgs.bashInteractive}/bin/bash -c '
            set -a
            source "$HERMES_ENV_FILE"
            set +a
            exec "$@"
          ' hermes-agent-maintenance "$@"
      '';
    };
  in {
    options.my.hermesRuntime = {
      enable = lib.mkEnableOption "the manually installed Hermes Agent gateway";

      user = lib.mkOption {
        type = lib.types.str;
        default = "hermes-agent";
        readOnly = true;
        description = "Dedicated unprivileged Hermes runtime account.";
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/hermes-agent";
        readOnly = true;
        description = "Hermes home and mutable state directory.";
      };

      executableDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.stateDir}/.nix-profile/bin";
        readOnly = true;
        description = "Manual Hermes profile binary directory.";
      };

      memoryMax = lib.mkOption {
        type = lib.types.str;
        default = "2G";
        description = "Hard memory limit for the Hermes gateway.";
      };

      cpuQuota = lib.mkOption {
        type = lib.types.str;
        default = "150%";
        description = "CPU quota for the Hermes gateway.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.networking.hostName == "hp-server";
          message = "Hermes runtime may only be enabled on hp-server.";
        }
      ];

      users.groups.${cfg.user} = {};
      users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.user;
        home = cfg.stateDir;
        createHome = true;
        shell = pkgs.bashInteractive;
        description = "Hermes Agent service account";
      };

      environment.systemPackages = [maintenance];

      systemd.services.hermes-agent = {
        description = "Hermes Agent messaging gateway";
        documentation = ["https://hermes-agent.nousresearch.com/docs/"];
        after = ["network-online.target" "sops-install-secrets.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        unitConfig = {
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
        };

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.user;
          WorkingDirectory = cfg.stateDir;
          EnvironmentFile = config.sops.templates."hermes-agent-env".path;
          Environment = [
            "HOME=${cfg.stateDir}"
            "PATH=${cfg.executableDir}:${runtimePath}"
          ];
          ExecStart = "${cfg.executableDir}/hermes gateway run --replace";
          Restart = "on-failure";
          RestartSec = 15;
          TimeoutStopSec = 60;

          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          RestrictSUIDSGID = true;
          LockPersonality = true;
          RemoveIPC = true;
          CapabilityBoundingSet = "";
          AmbientCapabilities = "";
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
          ReadWritePaths = [cfg.stateDir];
          UMask = "0077";

          TasksMax = 256;
          MemoryMax = cfg.memoryMax;
          CPUQuota = cfg.cpuQuota;
        };

        preStart = ''
          if [[ ! -x ${lib.escapeShellArg "${cfg.executableDir}/hermes"} ]]; then
            echo "Hermes is not installed for ${cfg.user}." >&2
            echo "Install it with:" >&2
            echo "  sudo hermes-agent-maintenance nix profile add github:NousResearch/hermes-agent/pull/19766/head" >&2
            exit 1
          fi

          if ! ${cfg.executableDir}/hermes --version >/dev/null; then
            echo "The manual Hermes executable is incompatible or broken." >&2
            echo "Repair it with:" >&2
            echo "See tasks/hermes-upstream-update.md before changing the known-good profile source." >&2
            exit 1
          fi
        '';
      };
    };
  };
}
