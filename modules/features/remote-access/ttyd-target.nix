{self, ...}: {
  flake.nixosModules.ttydWebTerminalTarget = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.ttydWebTerminalTarget;
    isLoopback = lib.elem cfg.listenAddress ["127.0.0.1" "::1"];
    isRemote = cfg.exposure == "tailscale";
    localSocket = "/run/ttyd-web-terminal/ttyd.sock";
    homeManagerService = "home-manager-${lib.replaceStrings ["-"] ["\\x2d"] cfg.user}.service";
    listenerArgs =
      if isLoopback
      then [
        "--interface"
        localSocket
        "--socket-owner"
        "${cfg.user}:ttyd-web-terminal"
      ]
      else [
        "--port"
        (toString cfg.port)
        "--interface"
        cfg.listenAddress
      ];
    ttydArgs =
      listenerArgs
      ++ [
        "--auth-header"
        cfg.authHeader
        "--writable"
        "--check-origin"
        "--max-clients"
        "1"
        "--base-path"
        cfg.basePath
        "--terminal-type"
        "xterm-256color"
        "--client-option"
        "titleFixed=${cfg.displayName}"
        "--cwd"
        cfg.workspace
        "--debug"
        "5"
        "${lib.getExe pkgs.tmux}"
        "new-session"
        "-A"
        "-s"
        cfg.tmuxSession
        "${lib.getExe pkgs.zsh}"
        "-l"
      ];
  in {
    options.my.ttydWebTerminalTarget = {
      enable = lib.mkEnableOption "a hardened ttyd web-terminal target";
      displayName = lib.mkOption {
        type = lib.types.nonEmptyStr;
        description = "Unambiguous host label shown by ttyd.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "code-shell";
        description = "Dedicated unprivileged Unix account for this target.";
      };
      workspace = lib.mkOption {
        type = lib.types.str;
        default = "/home/${cfg.user}/code";
        description = "Writable project directory for the terminal account.";
      };
      listenAddress = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Exact loopback or stable Tailscale address to bind.";
      };
      exposure = lib.mkOption {
        type = lib.types.enum ["loopback" "tailscale"];
        default = "loopback";
        description = "Whether ttyd is local to its gateway or source-restricted over Tailscale.";
      };
      gatewaySourceAddress = lib.mkOption {
        type = lib.types.nullOr (lib.types.strMatching "^100\\.[0-9]+\\.[0-9]+\\.[0-9]+$");
        default = null;
        description = "Stable Tailscale IPv4 of the sole gateway allowed to reach a remote target.";
      };
      tailscaleInterface = lib.mkOption {
        type = lib.types.str;
        default = "tailscale0";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 7681;
      };
      basePath = lib.mkOption {
        type = lib.types.strMatching "^/[a-z0-9-]+/$";
        default = "/hp/";
      };
      authHeader = lib.mkOption {
        type = lib.types.str;
        default = "X-TTYD-User";
        readOnly = true;
        description = "Header asserted only by the trusted gateway.";
      };
      tmuxSession = lib.mkOption {
        type = lib.types.strMatching "^[a-zA-Z0-9_-]+$";
        default = "web";
      };
      memoryHigh = lib.mkOption {
        type = lib.types.str;
        default = "1G";
      };
      memoryMax = lib.mkOption {
        type = lib.types.str;
        default = "1536M";
      };
      memorySwapMax = lib.mkOption {
        type = lib.types.str;
        default = "1G";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = (cfg.exposure == "loopback") == isLoopback;
          message = "A loopback ttyd target must bind to loopback and a Tailscale target must not.";
        }
        {
          assertion = !isRemote || (lib.hasPrefix "100." cfg.listenAddress && cfg.gatewaySourceAddress != null);
          message = "A Tailscale ttyd target requires its stable 100.x address and the gateway's stable Tailscale IPv4.";
        }
        {
          assertion = !isRemote || (config.services.tailscale.enable && config.networking.firewall.backend == "nftables");
          message = "A remote ttyd target requires Tailscale and the nftables firewall backend for source-restricted ingress.";
        }
        {
          assertion = cfg.user != "root" && !(lib.elem cfg.user config.nix.settings.trusted-users);
          message = "The ttyd account must not be root or a trusted Nix user.";
        }
        {
          assertion = !(lib.elem cfg.user config.users.groups.wheel.members);
          message = "The ttyd account must not be a wheel member.";
        }
        {
          assertion = !(lib.elem cfg.user config.users.groups.docker.members);
          message = "The ttyd account must not be a Docker group member because Docker access is root-equivalent.";
        }
        {
          assertion = cfg.workspace == "/home/${cfg.user}" || lib.hasPrefix "/home/${cfg.user}/" cfg.workspace;
          message = "The ttyd workspace must remain inside the dedicated account home.";
        }
      ];

      users.groups.${cfg.user} = {};
      users.groups.ttyd-web-terminal = lib.mkIf isLoopback {
        members = [cfg.user "nginx"];
      };
      users.users.${cfg.user} = {
        # This must not be a normal user: the shared Docker module grants every
        # normal user root-equivalent Docker access. ttyd starts this account
        # directly, so it does not need PAM/SSH login eligibility.
        isSystemUser = true;
        group = cfg.user;
        home = "/home/${cfg.user}";
        createHome = true;
        shell = pkgs.zsh;
        extraGroups = [];
      };

      home-manager.users.${cfg.user} = {
        nixpkgs.config.allowUnfree = true;
        home.username = cfg.user;
        home.homeDirectory = "/home/${cfg.user}";
        home.stateVersion = "25.05";
        programs.home-manager.enable = true;
        my.account.role = "restricted-code-shell";
      };

      systemd.tmpfiles.rules =
        [
          "d ${cfg.workspace} 0700 ${cfg.user} ${cfg.user} -"
        ]
        ++ lib.optional isLoopback "d /run/ttyd-web-terminal 0750 ${cfg.user} ttyd-web-terminal -";

      systemd.slices.ttyd-web-terminal = {
        description = "Resource boundary for browser terminal workloads";
        sliceConfig = {
          MemoryHigh = cfg.memoryHigh;
          MemoryMax = cfg.memoryMax;
          MemorySwapMax = cfg.memorySwapMax;
          TasksMax = 512;
          CPUQuota = "200%";
          ManagedOOMMemoryPressure = "kill";
          ManagedOOMMemoryPressureLimit = "80%";
        };
      };

      systemd.services.ttyd-web-terminal = {
        description = "Hardened ttyd browser terminal for ${cfg.displayName}";
        wantedBy = ["multi-user.target"];
        after = ["network.target" homeManagerService];
        requires = [homeManagerService];
        serviceConfig = {
          User = cfg.user;
          Group = cfg.user;
          Slice = "ttyd-web-terminal.slice";
          WorkingDirectory = cfg.workspace;
          ExecStart = "${lib.getExe pkgs.ttyd} ${lib.escapeShellArgs ttydArgs}";
          Restart = "on-failure";
          RestartSec = "5s";
          UMask = "0077";
          Environment = [
            "HOME=/home/${cfg.user}"
            "USER=${cfg.user}"
            "LOGNAME=${cfg.user}"
            "TERM=xterm-256color"
            "PATH=/etc/profiles/per-user/${cfg.user}/bin:${lib.makeBinPath [pkgs.coreutils pkgs.git pkgs.nix pkgs.tmux pkgs.zsh]}"
          ];
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          ProtectHome = "tmpfs";
          BindPaths = [
            "/home/${cfg.user}"
            cfg.workspace
          ];
          # The listener remains a Unix socket locally, but coding tools need
          # outbound IPv4/IPv6 for Git and package registries.
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          LockPersonality = true;
          # JIT runtimes such as Node.js require executable memory mappings.
          MemoryDenyWriteExecute = false;
          CapabilityBoundingSet = "";
          SystemCallArchitectures = "native";
          # libwebsockets uses chown(2) to assign its Unix socket to the narrow
          # nginx transport group. The service has no capabilities and cannot
          # chown files it does not own.
          SystemCallFilter = ["@system-service" "chown" "~@resources"];
        };
      };

      networking.firewall.extraInputRules = lib.mkIf isRemote ''
        iifname "${cfg.tailscaleInterface}" ip saddr ${cfg.gatewaySourceAddress} tcp dport ${toString cfg.port} accept
      '';
    };
  };
}
