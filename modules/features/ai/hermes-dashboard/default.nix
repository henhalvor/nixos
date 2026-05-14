{inputs, ...}: {
  flake.nixosModules.hermesDashboard = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.hermesDashboard;
    ownerHome = lib.attrByPath ["users" "users" cfg.ownerUser "home"] "/home/${cfg.ownerUser}" config;
  in {
    options.my.hermesDashboard = {
      enable = lib.mkEnableOption ''
        Hermes dashboard exposed via Tailscale Serve with a persistent systemd service
      '';

      ownerUser = lib.mkOption {
        type = lib.types.str;
        default = "henhal";
        description = "User whose hermes dashboard to run.";
      };

      dashboardPort = lib.mkOption {
        type = lib.types.port;
        default = 9119;
        description = "Port the Hermes dashboard listens on.";
      };

      proxyPort = lib.mkOption {
        type = lib.types.port;
        default = 9120;
        description = "Local loopback reverse-proxy port exposed through Tailscale Serve.";
      };
    };

    config = lib.mkIf cfg.enable {
      services.nginx = {
        enable = true;
        virtualHosts.hermes-dashboard = {
          listen = [
            {
              addr = "127.0.0.1";
              port = cfg.proxyPort;
            }
          ];
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.dashboardPort}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host 127.0.0.1:${toString cfg.dashboardPort};
              proxy_set_header X-Forwarded-Host $host;
              proxy_set_header X-Forwarded-Proto https;
            '';
          };
        };
      };

      systemd.services.hermes-dashboard = {
        description = "Hermes Agent Web Dashboard + Tailscale Serve";
        documentation = ["https://hermes-agent.nousresearch.com/docs/"];
        after = ["network-online.target" "tailscaled.service" "nginx.service"];
        wants = ["network-online.target" "nginx.service"];
        wantedBy = ["multi-user.target"];

        # Runs as root because tailscale serve needs root to talk to tailscaled.
        # Dashboard itself runs as the owner user via sudo -u.
        serviceConfig = {
          Type = "simple";
          User = "root";
          WorkingDirectory = ownerHome;
          Restart = "on-failure";
          RestartSec = 10;
          # Keep the env clean — sudo -u will pick up the user's nix-profile PATH
          Environment = "PATH=/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";
        };

        script = ''
          set -euo pipefail

          # Register Tailscale Serve to proxy the local nginx frontend onto the tailnet.
          # Nginx rewrites Host to 127.0.0.1 so Hermes' loopback Host-header
          # protection still passes when accessed through the MagicDNS name.
          # at https://<node>.tail<XXXX>.ts.net/ with auto HTTPS certs.
          # This config is persistent in tailscale state (survives reboots)
          # and is idempotent — rerunning is safe.
          ${lib.getExe pkgs.tailscale} serve --bg ${toString cfg.proxyPort}

          # Launch the dashboard itself — still bound to localhost only.
          # Tailscale Serve handles the tailnet-facing proxy securely.
          exec sudo -u ${cfg.ownerUser} \
            ${ownerHome}/.nix-profile/bin/hermes dashboard \
            --host 127.0.0.1 \
            --port ${toString cfg.dashboardPort} \
            --no-open
        '';

        postStop = ''
          # Clean up the proxy on stop so we don't leave stale routes
          ${lib.getExe pkgs.tailscale} serve --https=443 off 2>/dev/null || true
        '';
      };
    };
  };
}
