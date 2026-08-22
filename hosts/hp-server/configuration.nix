# HP Server — headless Hermes, Firecrawl, and synchronization host
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.hpServerConfig =
    { pkgs, ... }:
    {
      imports = [
        self.nixosModules.hpServerHardware
        self.nixosModules.base
        self.nixosModules.bootloader
        self.nixosModules.networking
        self.nixosModules.garbageCollection
        inputs.home-manager.nixosModules.home-manager
        inputs.stylix.nixosModules.stylix
        self.nixosModules.stylix

        self.nixosModules.systemdLogind
        self.nixosModules.docker
        self.nixosModules.syncthing
        self.nixosModules.laptopServer
        self.nixosModules.sshServer
        self.nixosModules.tailscale
        self.nixosModules.monitoringExporter
        self.nixosModules.monitoringHub

        self.nixosModules.nvim
        self.nixosModules.zsh
        self.nixosModules.tmux
        self.nixosModules.yazi
        self.nixosModules.git
        self.nixosModules.sshConfig
        self.nixosModules.secrets
        self.nixosModules.devTools
        self.nixosModules.sessionVariables
        self.nixosModules.direnv
        self.nixosModules.devShellBootstrap
        self.nixosModules.utils

        # self.nixosModules.firecrawl
        # self.nixosModules.hermesRuntime
        # self.nixosModules.hermesDashboard
        # self.nixosModules.hermesWorkspace

        # Phase 5 services are imported now but intentionally not enabled until
        # the real domain, tunnel UUID, S3 identity, and encrypted SOPS profiles
        # have been created.  See docs/runbooks/phase-5-deployment.md.
        self.nixosModules.opencloud
        self.nixosModules.opencloudRadicale
        self.nixosModules.opencloudKeycloak
        self.nixosModules.opencloudTunnel
        self.nixosModules.opencloudConsistentSource
        self.nixosModules.githubMirror
        self.nixosModules.hpResticS3

        self.nixosModules.userHenhal
      ];

      networking.hostName = "hp-server";
      system.stateVersion = "25.05";
      systemd.defaultUnit = "multi-user.target";

      # Keep agent-triggered builds from exhausting this 8 GiB host.
      nix.settings = {
        # Permit the administrative SSH user to import locally-built closures
        # when deploying this host remotely. henhal is already a wheel user.
        trusted-users = [ "henhal" ];

        # Avoid multiple large builds competing for the host's limited memory.
        "max-jobs" = 1;
        cores = 1;
      };

      # Compressed in-memory swap gives the kernel room to recover from short
      # memory spikes without touching disk or requiring a disk swap device.
      zramSwap = {
        enable = true;
        memoryPercent = 50;
        algorithm = "zstd";
      };

      # Interactive agent/build jobs must be launched with `agent-run` below so
      # they cannot consume the whole machine. Keep SSH, Tailscale, and system
      # services outside this slice.
      systemd.user.slices.agent-build = {
        sliceConfig = {
          MemoryHigh = "2G";
          MemoryMax = "3G";
          MemorySwapMax = "2G";
          ManagedOOMMemoryPressure = "kill";
          ManagedOOMMemoryPressureLimit = "80%";
        };
      };

      environment.systemPackages = [
        pkgs.kitty.terminfo
        (pkgs.writeShellApplication {
          name = "agent-run";
          runtimeInputs = [ pkgs.systemd ];
          text = ''
            exec systemd-run --user --scope \
              --slice=agent-build.slice \
              "$@"
          '';
        })
      ];

      # The gateway already has a 2G hard limit in hermes-runtime.nix; reduce
      # it here for this 8 GiB host while leaving room for core services.
      # my.hermesRuntime.memoryMax = "1536M";

      my.syncthing = {
        user = "henhal";
        deviceName = "hp-server";
        identitySopsFile = ../../secrets/syncthing/hp-server.yaml;
      };

      my.opencloud = {
        enable = true;
        cloudHost = "cloud.henhal.net";
        authHost = "auth.henhal.net";
        radicale.enable = true;
      };

      # Passing the montoring hub URL to cloudflare tunnel "owned" by opencloud service
      my.opencloudTunnel.extraIngress."monitor.henhal.net" = {
        service = "http://127.0.0.1:3000";
        httpHostHeader = "monitor.henhal.net";
      };

      my.opencloudConsistentSource.enable = true;
      my.githubMirror.enable = true;
      my.hpBackup = {
        enable = true;
        # Built-in staged/exported sources must not be repeated here:
        # /run/opencloud-backup/current, /var/lib/opencloud-identity-backup,
        # /var/lib/{vault,shared,radicale}-backup,
        # /var/lib/github-mirrors, and /var/lib/hermes-backup. This list is
        # only ordinary HP-local files that may be read live by Restic.
        extraPaths = [
          "/home/henhal/Documents"
          "/home/henhal/Pictures"
          "/home/henhal/Music"
          "/home/henhal/Downloads"
          "/home/henhal/Video"
          "/home/henhal/Desktop"
        ];
      };

      my.opencloudTunnel.tunnelId = "d5383138-72c4-4879-924a-319edc4c20c6";

      # Monitoring is initially private while the dedicated Keycloak client,
      # SOPS receiver credentials, external heartbeat, and Cloudflare DNS route
      # are created. The full metrics/log/dashboard stack is already active;
      # enable OIDC and tunnel ingress only after completing the deployment
      # gates in docs/MONITORING.md.
      my.monitoring.exporter = {
        enable = true;
        hubHost = "100.71.100.37";
        journalMaxUse = "2G";
        enableBackupMetrics = true;
        enableSyncthingMetrics = true;
        extraUnits = [
          "opencloud.service"
          "keycloak.service"
          "postgresql.service"
          "cloudflared-tunnel-d5383138-72c4-4879-924a-319edc4c20c6.service"
          "restic-backups-hp-offsite.service"
          "restic-hp-offsite-check.service"
          "github-mirror.service"
          "radicale.service"
          "radicale-backup-stage.service"
          "syncthing.service"
          # "firecrawl.service"
          # "hermes-agent.service"
        ];
        fullJournalUnits = [
          "opencloud.service"
          "keycloak.service"
          "cloudflared-tunnel-d5383138-72c4-4879-924a-319edc4c20c6.service"
          "restic-backups-hp-offsite.service"
          "github-mirror.service"
          # "firecrawl.service"
          # "hermes-agent.service"
        ];
      };
      my.monitoring.hub = {
        enable = true;
        enableOidc = true;
        enableNotifications = true;
        enableHeartbeats = true;
        secretFile = ../../secrets/monitoring.yaml;
        lokiPushListenAddress = "100.71.100.37";

        localProbeTargets = {
          grafana = "http://127.0.0.1:3000/api/health";
          keycloak = "http://127.0.0.1:8080/realms/opencloud/.well-known/openid-configuration";
          opencloud = "http://127.0.0.1:9200/";
        };
        scrapeTargets = {
          hp-server = "127.0.0.1";
          workstation = "workstation.tail37a5eb.ts.net";
          lenovo-yoga-pro-7 = "lenovo-yoga-pro-7.tail37a5eb.ts.net";
        };
      };

      # my.hermesRuntime.enable = true;
      # my.hermesDashboard.enable = true;
      # my.hermesWorkspace = {
      #   enable = true;
      #   # Grafana owns the conventional loopback port 3000. Workspace remains
      #   # exposed through its unchanged Tailscale HTTPS port 3001.
      #   workspacePort = 3003;
      # };

      # Driver for the USB-C Ethernet adapter.
      boot.kernelModules = [ "ax88179_178a" ];

      home-manager = {
        useGlobalPkgs = false;
        useUserPackages = true;
        backupFileExtension = "hm-backup";
        extraSpecialArgs = {
          inherit inputs self;
          pkgs-unstable = import inputs.nixpkgs-unstable {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
          pkgs24-11 = import inputs.nixpkgs-24-11 {
            system = "x86_64-linux";
            config.allowUnfree = true;
          };
        };
      };
    };
}
