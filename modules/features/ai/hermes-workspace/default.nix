{inputs, ...}: {
  flake.nixosModules.hermesWorkspace = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.hermesWorkspace;
    ownerHome = lib.attrByPath ["users" "users" cfg.ownerUser "home"] "/home/${cfg.ownerUser}" config;
  in {
    options.my.hermesWorkspace = {
      enable = lib.mkEnableOption ''
        Hermes Workspace exposed via Tailscale Serve with a persistent systemd service
      '';

      ownerUser = lib.mkOption {
        type = lib.types.str;
        default = "henhal";
        description = "User whose Hermes Workspace checkout and runtime to use.";
      };

      workspaceDir = lib.mkOption {
        type = lib.types.str;
        default = "${ownerHome}/hermes-workspace";
        description = "Absolute path to the Hermes Workspace checkout.";
      };

      workspacePort = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Local loopback port Hermes Workspace listens on.";
      };

      tailscaleHttpsPort = lib.mkOption {
        type = lib.types.port;
        default = 3001;
        description = "Tailnet HTTPS port exposed through Tailscale Serve.";
      };

      hermesApiUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8642";
        description = "Hermes Agent gateway API URL used by Workspace.";
      };

      hermesDashboardUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:9119";
        description = "Hermes Agent dashboard URL used by Workspace for enhanced APIs.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.tailscaleHttpsPort != 443;
          message = "my.hermesWorkspace.tailscaleHttpsPort must not be 443 because hermesDashboard already owns the root Tailscale Serve route.";
        }
      ];

      environment.systemPackages = with pkgs; [
        git
        nodejs_22
        pnpm
      ];

      sops.secrets.HERMES_WORKSPACE_PASSWORD = {
        owner = cfg.ownerUser;
        group = "keys";
        mode = "0440";
      };

      sops.templates."hermes-workspace-env" = {
        owner = cfg.ownerUser;
        group = "users";
        mode = "0440";
        content = ''
          PORT=${toString cfg.workspacePort}
          HOST=127.0.0.1
          NODE_ENV=production
          HERMES_API_URL=${cfg.hermesApiUrl}
          HERMES_DASHBOARD_URL=${cfg.hermesDashboardUrl}
          HERMES_PASSWORD=${config.sops.placeholder.HERMES_WORKSPACE_PASSWORD}
          COOKIE_SECURE=1
          TRUST_PROXY=1
        '';
      };

      systemd.services.hermes-workspace = {
        description = "Hermes Workspace + Tailscale Serve";
        documentation = ["https://github.com/outsourc-e/hermes-workspace"];
        after = ["network-online.target" "tailscaled.service" "hermes-dashboard.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        # Runs as root because tailscale serve needs root to talk to tailscaled.
        # Workspace itself runs as the owner user via sudo -u.
        serviceConfig = {
          Type = "simple";
          User = "root";
          WorkingDirectory = cfg.workspaceDir;
          Restart = "on-failure";
          RestartSec = 10;
          EnvironmentFile = config.sops.templates."hermes-workspace-env".path;
          Environment = "PATH=${lib.makeBinPath [pkgs.nodejs_22 pkgs.pnpm pkgs.git pkgs.tailscale pkgs.sudo pkgs.coreutils]}";
        };

        preStart = ''
          set -euo pipefail
          if [ ! -f ${lib.escapeShellArg cfg.workspaceDir}/server-entry.js ]; then
            echo "Hermes Workspace is not cloned at ${cfg.workspaceDir}" >&2
            exit 1
          fi
          if [ ! -d ${lib.escapeShellArg cfg.workspaceDir}/dist ]; then
            echo "Hermes Workspace is not built at ${cfg.workspaceDir}; run pnpm install && pnpm build" >&2
            exit 1
          fi
        '';

        script = ''
          set -euo pipefail

          # Expose Workspace on a separate HTTPS port so it does not replace
          # the existing dashboard route at https://<node>.tail<id>.ts.net/.
          ${lib.getExe pkgs.tailscale} serve --bg --https=${toString cfg.tailscaleHttpsPort} ${toString cfg.workspacePort}

          exec sudo -u ${cfg.ownerUser} \
            --preserve-env=PORT,HOST,NODE_ENV,HERMES_API_URL,HERMES_DASHBOARD_URL,HERMES_PASSWORD,COOKIE_SECURE,TRUST_PROXY \
            ${pkgs.nodejs_22}/bin/node \
            ${cfg.workspaceDir}/server-entry.js
        '';

        postStop = ''
          ${lib.getExe pkgs.tailscale} serve --https=${toString cfg.tailscaleHttpsPort} off 2>/dev/null || true
        '';
      };
    };
  };
}
