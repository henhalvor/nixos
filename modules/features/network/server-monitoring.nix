# Server Monitoring — Prometheus + Grafana
# Source: nixos/modules/server/server-monitoring.nix
{...}: {
  flake.nixosModules.serverMonitoring = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [prometheus grafana];

    services.prometheus = {
      enable = true;
      port = 9090;
      retentionTime = "15d";

      exporters.node = {
        enable = true;
        enabledCollectors = [
          "systemd"
          "processes"
          "filesystem"
          "diskstats"
          "cpu"
          "meminfo"
          "netdev"
          "loadavg"
        ];
        port = 9100;
      };

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = ["localhost:9100"];
              labels.instance = "nixos-server";
            }
          ];
        }
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = ["localhost:9090"];
              labels.instance = "prometheus";
            }
          ];
        }
      ];
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "0.0.0.0";
          http_port = 4000;
          domain = "10.0.0.120";
          root_url = "http://10.0.0.120:4000/";
        };
        security = {
          admin_user = "admin";
          admin_password = "StrongPassword123";
        };
        analytics.reporting_enabled = false;
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://localhost:9090";
            isDefault = true;
          }
        ];
      };
    };

    networking.firewall.allowedTCPPorts = [9090 9100 4000];
  };
}
