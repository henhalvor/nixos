# Monitoring hub for hp-server.  All public access is intentionally delegated
# to the existing Cloudflare Tunnel; every backend remains loopback-only except
# for the narrow Tailscale Loki push proxy.
{ ... }:
{
  flake.nixosModules.monitoringHub =
    { config, lib, pkgs, ... }:
    let
      cfg = config.my.monitoring.hub;
      monitoringDir = "/var/lib/monitoring";
      dashboardDir = ./dashboards;
      ruleDir = ./rules;
      hasDashboards = builtins.pathExists dashboardDir;
      hasRules = builtins.pathExists ruleDir;

      nodeStaticConfigs = lib.mapAttrsToList (host: target: {
        targets = [ "${target}:${toString cfg.nodeExporterPort}" ];
        labels.host = host;
      }) cfg.scrapeTargets;

      blackboxTargets = map (host: "https://${host}") (
        (lib.optional cfg.enableOidc cfg.publicHost) ++ [ cfg.authHost ] ++ cfg.extraPublicProbeHosts
      );
      localProbeStaticConfigs = lib.mapAttrsToList (service: target: {
        targets = [ target ];
        labels = {
          inherit service;
          host = "hp-server";
        };
      }) cfg.localProbeTargets;

      blackboxRelabelConfigs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "127.0.0.1:${toString cfg.blackboxPort}";
        }
      ];

      # Keep a missing secret as a runtime-only placeholder so the assertions
      # below produce a useful evaluation error instead of an interpolation
      # failure while evaluating the Grafana settings.
      grafanaFile = path: "$__file{${if path == null then "/run/secrets/monitoring-missing" else path}}";
      sendHeartbeat = pkgs.writeShellApplication {
        name = "monitoring-send-heartbeat";
        runtimeInputs = with pkgs; [coreutils curl];
        text = ''
          url_file="$1"
          [[ -r "$url_file" ]] || { echo "heartbeat URL file is unreadable" >&2; exit 1; }
          heartbeat_url="$(tr -d '\r\n' <"$url_file")"
          [[ "$heartbeat_url" == https://* ]] || { echo "heartbeat URL must use HTTPS" >&2; exit 1; }
          # Feed the secret URL over stdin instead of exposing its token in the
          # process list. Curl errors are intentionally not run in verbose mode.
          escaped="''${heartbeat_url//\\/\\\\}"
          escaped="''${escaped//\"/\\\"}"
          printf 'url = "%s"\n' "$escaped" \
            | curl --config - --fail --silent --show-error --max-time 15 \
                --retry 2 --output /dev/null
        '';
      };
      stackHeartbeat = pkgs.writeShellApplication {
        name = "monitoring-stack-heartbeat";
        runtimeInputs = with pkgs; [curl];
        text = ''
          curl --fail --silent --show-error --max-time 5 http://127.0.0.1:9090/-/ready >/dev/null
          curl --fail --silent --show-error --max-time 5 http://127.0.0.1:9093/-/ready >/dev/null
          curl --fail --silent --show-error --max-time 5 http://127.0.0.1:3100/ready >/dev/null
          curl --fail --silent --show-error --max-time 5 http://127.0.0.1:3000/api/health >/dev/null
          exec ${sendHeartbeat}/bin/monitoring-send-heartbeat "$1"
        '';
      };
    in
    {
      options.my.monitoring.hub = {
        enable = lib.mkEnableOption "the private HP monitoring hub";

        enableOidc = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Keycloak login after the monitoring realm, client, and SOPS secrets exist.";
        };
        enableNotifications = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the external Alertmanager receiver after its SOPS environment file exists.";
        };
        enableHeartbeats = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable independent external stack and backup-success heartbeats after their SOPS URL files exist.";
        };
        secretFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "SOPS YAML containing Grafana, Alertmanager, and heartbeat secrets; leave null during private bootstrap.";
        };
        stackHeartbeatUrlFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Root-readable file containing the external monitoring-stack heartbeat URL.";
        };
        backupHeartbeatUrlFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Root-readable file containing the external nightly-backup success heartbeat URL.";
        };

        publicHost = lib.mkOption {
          type = lib.types.str;
          default = "monitor.henhal.net";
          description = "Public Grafana hostname, served only by Cloudflare Tunnel.";
        };
        authHost = lib.mkOption {
          type = lib.types.str;
          default = "auth.henhal.net";
          description = "Public Keycloak hostname used by Grafana Generic OAuth.";
        };
        oidcRealm = lib.mkOption {
          type = lib.types.str;
          default = "monitoring";
        };
        oidcClientId = lib.mkOption {
          type = lib.types.str;
          default = "grafana";
        };
        oidcClientSecretFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Root-readable runtime file containing the Keycloak client secret.";
        };
        grafanaAdminPasswordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Root-readable runtime file with the break-glass Grafana admin password.";
        };
        grafanaSecretKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Root-readable runtime file with Grafana's persistent session-signing secret.";
        };
        alertmanagerEnvironmentFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Root-readable environment file containing monitoring Telegram receiver values.";
        };

        scrapeTargets = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            hp-server = "hp-server";
            workstation = "workstation";
            lenovo-yoga-pro-7 = "lenovo-yoga-pro-7";
          };
          description = "Stable Tailscale DNS names or IP addresses for Node Exporter targets.";
        };
        tailscaleInterface = lib.mkOption {
          type = lib.types.str;
          default = "tailscale0";
        };
        lokiPushListenAddress = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "100.64.0.10";
          description = "HP's stable Tailscale address used solely by the Loki push nginx listener.";
        };
        lokiPushPort = lib.mkOption {
          type = lib.types.port;
          default = 3101;
        };
        nodeExporterPort = lib.mkOption {
          type = lib.types.port;
          default = 9300;
        };
        blackboxPort = lib.mkOption {
          type = lib.types.port;
          default = 9315;
        };
        prometheusRetention = lib.mkOption {
          type = lib.types.str;
          default = "30d";
        };
        prometheusRetentionSize = lib.mkOption {
          type = lib.types.str;
          default = "15GB";
          description = "Prometheus TSDB size ceiling passed directly to Prometheus.";
        };
        lokiRetention = lib.mkOption {
          type = lib.types.str;
          default = "14d";
        };
        extraPublicProbeHosts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "cloud.henhal.net" ];
        };
        localProbeTargets = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            grafana = "http://127.0.0.1:3000/api/health";
            keycloak = "http://127.0.0.1:8080/realms/opencloud/.well-known/openid-configuration";
            opencloud = "http://127.0.0.1:9200/";
            firecrawl = "http://127.0.0.1:3002/";
            hermes-dashboard = "http://127.0.0.1:9120/";
          };
          description = "Safe loopback HTTP endpoints probed from HP without exposing them publicly.";
        };
      };

      config = lib.mkIf cfg.enable {
        my.monitoring.hub = lib.mkMerge [
          (lib.mkIf (cfg.secretFile != null && cfg.enableOidc) {
            oidcClientSecretFile = lib.mkDefault config.sops.secrets.GRAFANA_OAUTH_CLIENT_SECRET.path;
            grafanaAdminPasswordFile = lib.mkDefault config.sops.secrets.GRAFANA_ADMIN_PASSWORD.path;
            grafanaSecretKeyFile = lib.mkDefault config.sops.secrets.GRAFANA_SECRET_KEY.path;
          })
          (lib.mkIf (cfg.secretFile != null && cfg.enableNotifications) {
            alertmanagerEnvironmentFile = lib.mkDefault config.sops.templates."monitoring-alertmanager-env".path;
          })
          (lib.mkIf (cfg.secretFile != null && cfg.enableHeartbeats) {
            stackHeartbeatUrlFile = lib.mkDefault config.sops.secrets.MONITORING_STACK_HEARTBEAT_URL.path;
            backupHeartbeatUrlFile = lib.mkDefault config.sops.secrets.MONITORING_BACKUP_HEARTBEAT_URL.path;
          })
        ];
        my.hpBackup = lib.mkIf (cfg.secretFile != null && cfg.enableHeartbeats) {
          enableSuccessHeartbeat = true;
          successHeartbeatUrlFile = config.sops.secrets.MONITORING_BACKUP_HEARTBEAT_URL.path;
        };

        sops.secrets = lib.mkMerge [
          (lib.mkIf (cfg.secretFile != null && cfg.enableOidc) {
            GRAFANA_OAUTH_CLIENT_SECRET = {
              sopsFile = cfg.secretFile;
              owner = "grafana";
              group = "grafana";
              mode = "0400";
            };
            GRAFANA_ADMIN_PASSWORD = {
              sopsFile = cfg.secretFile;
              owner = "grafana";
              group = "grafana";
              mode = "0400";
            };
            GRAFANA_SECRET_KEY = {
              sopsFile = cfg.secretFile;
              owner = "grafana";
              group = "grafana";
              mode = "0400";
            };
          })
          (lib.mkIf (cfg.secretFile != null && cfg.enableNotifications) {
            MONITORING_TELEGRAM_BOT_TOKEN = { sopsFile = cfg.secretFile; mode = "0400"; };
            MONITORING_TELEGRAM_CHAT_ID = { sopsFile = cfg.secretFile; mode = "0400"; };
          })
          (lib.mkIf (cfg.secretFile != null && cfg.enableHeartbeats) {
            MONITORING_STACK_HEARTBEAT_URL = { sopsFile = cfg.secretFile; mode = "0400"; };
            MONITORING_BACKUP_HEARTBEAT_URL = { sopsFile = cfg.secretFile; mode = "0400"; };
          })
        ];
        sops.templates."monitoring-alertmanager-env" = lib.mkIf (cfg.secretFile != null && cfg.enableNotifications) {
          owner = "root";
          group = "root";
          mode = "0400";
          content = ''
            MONITORING_TELEGRAM_BOT_TOKEN=${config.sops.placeholder.MONITORING_TELEGRAM_BOT_TOKEN}
            MONITORING_TELEGRAM_CHAT_ID=${config.sops.placeholder.MONITORING_TELEGRAM_CHAT_ID}
          '';
        };

        assertions = [
          {
            assertion = config.networking.hostName == "hp-server";
            message = "my.monitoring.hub is only supported on hp-server.";
          }
          {
            assertion = cfg.publicHost != "" && cfg.authHost != "";
            message = "my.monitoring.hub publicHost and authHost must be nonempty.";
          }
          {
            assertion = !cfg.enableOidc || cfg.oidcClientSecretFile != null;
            message = "my.monitoring.hub.oidcClientSecretFile must reference a SOPS runtime secret when OIDC is enabled.";
          }
          {
            assertion = !cfg.enableOidc || (cfg.grafanaAdminPasswordFile != null && cfg.grafanaSecretKeyFile != null);
            message = "Grafana break-glass password and session secret must be SOPS runtime files when OIDC is enabled.";
          }
          {
            assertion = !cfg.enableNotifications || cfg.alertmanagerEnvironmentFile != null;
            message = "my.monitoring.hub.alertmanagerEnvironmentFile must provide receiver secrets when notifications are enabled.";
          }
          {
            assertion = !cfg.enableHeartbeats || (cfg.stackHeartbeatUrlFile != null && cfg.backupHeartbeatUrlFile != null);
            message = "Both external heartbeat URL files are required when monitoring heartbeats are enabled.";
          }
          {
            assertion = cfg.lokiPushListenAddress != null;
            message = "my.monitoring.hub.lokiPushListenAddress must be HP's stable Tailscale IP.";
          }
          {
            assertion = cfg.scrapeTargets != { };
            message = "my.monitoring.hub.scrapeTargets must contain at least hp-server.";
          }
        ];

        # Monitoring data is deliberately on the HP system disk. It is useful
        # operational state, not irreplaceable data that belongs on the T7/R2.
        systemd.tmpfiles.rules = [
          "d ${monitoringDir} 0755 root root -"
          "d ${monitoringDir}/prometheus 0750 prometheus prometheus -"
          "d ${monitoringDir}/loki 0750 loki loki -"
          "d ${monitoringDir}/alertmanager 0750 root root -"
        ];
        services.prometheus = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9090;
          stateDir = "monitoring/prometheus";
          retentionTime = cfg.prometheusRetention;
          extraFlags = [ "--storage.tsdb.retention.size=${cfg.prometheusRetentionSize}" ];
          alertmanagers = [ { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; } ];
          ruleFiles = lib.optionals hasRules (
            lib.filter (path: lib.hasSuffix ".yaml" (toString path))
              (lib.filesystem.listFilesRecursive ruleDir)
          );
          scrapeConfigs = [
            {
              job_name = "node";
              scrape_interval = "30s";
              static_configs = nodeStaticConfigs;
            }
            {
              job_name = "prometheus";
              scrape_interval = "30s";
              static_configs = [ { targets = [ "127.0.0.1:9090" ]; labels.host = "hp-server"; } ];
            }
            {
              job_name = "alertmanager";
              scrape_interval = "30s";
              static_configs = [ { targets = [ "127.0.0.1:9093" ]; labels.host = "hp-server"; } ];
            }
            {
              job_name = "loki";
              scrape_interval = "30s";
              static_configs = [ { targets = [ "127.0.0.1:3100" ]; labels.host = "hp-server"; } ];
            }
            {
              job_name = "grafana";
              scrape_interval = "30s";
              metrics_path = "/metrics";
              static_configs = [ { targets = [ "127.0.0.1:3000" ]; labels.host = "hp-server"; } ];
            }
            {
              job_name = "blackbox-http";
              scrape_interval = "60s";
              metrics_path = "/probe";
              params.module = [ "http_2xx" ];
              static_configs = [ { targets = blackboxTargets; } ];
              relabel_configs = blackboxRelabelConfigs;
            }
            {
              job_name = "blackbox-local";
              scrape_interval = "30s";
              metrics_path = "/probe";
              params.module = [ "http_local" ];
              static_configs = localProbeStaticConfigs;
              relabel_configs = blackboxRelabelConfigs;
            }
          ];
        };

        services.prometheus.alertmanager = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9093;
          environmentFile = lib.mkIf cfg.enableNotifications cfg.alertmanagerEnvironmentFile;
          # amtool cannot see SOPS runtime variables during build.
          checkConfig = false;
          # Raw YAML keeps Telegram chat_id numeric after the NixOS module's
          # envsubst pass; a structured Nix value would quote the placeholder.
          configText = if cfg.enableNotifications then ''
              route:
                receiver: telegram
                group_by: [alertname, host, component]
                group_wait: 30s
                group_interval: 5m
                repeat_interval: 12h
                routes:
                  # These conditions remain visible in Prometheus and Grafana,
                  # but are intentionally non-actionable until their deferred
                  # implementation/capacity work is resumed.
                  - receiver: local-null
                    matchers: ['alertname = BackupSourceDegraded', 'source = hermes']
                  - receiver: local-null
                    matchers: ['alertname = BackupSourceStillDegraded', 'source = hermes']
                  - receiver: local-null
                    matchers: ['alertname = NixStoreLarge']
                  - receiver: telegram
                    matchers: ['severity = critical']
                    repeat_interval: 4h
                  - receiver: telegram
                    matchers: ['severity = warning']
                    repeat_interval: 12h
              receivers:
                - name: local-null
                - name: telegram
                  telegram_configs:
                    - bot_token: ''${MONITORING_TELEGRAM_BOT_TOKEN}
                      chat_id: ''${MONITORING_TELEGRAM_CHAT_ID}
                      send_resolved: true
              inhibit_rules:
                - source_matchers: ['severity = critical']
                  target_matchers: ['severity = warning']
                  equal: [host, component]
            '' else ''
              route:
                receiver: local-null
                group_by: [alertname, host, component]
              receivers:
                - name: local-null
              inhibit_rules:
                - source_matchers: ['severity = critical']
                  target_matchers: ['severity = warning']
                  equal: [host, component]
            '';
        };

        services.loki = {
          enable = true;
          dataDir = "${monitoringDir}/loki";
          configuration = {
            auth_enabled = false;
            server = {
              http_listen_address = "127.0.0.1";
              http_listen_port = 3100;
              grpc_listen_address = "127.0.0.1";
              grpc_listen_port = 9096;
            };
            common = {
              path_prefix = "${monitoringDir}/loki";
              replication_factor = 1;
              # Loki otherwise auto-selects HP's Docker bridge address for the
              # query frontend callback even though gRPC is loopback-only.
              instance_addr = "127.0.0.1";
              ring = {
                instance_addr = "127.0.0.1";
                kvstore.store = "inmemory";
              };
            };
            schema_config.configs = [
              {
                from = "2024-01-01";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
            limits_config = {
              retention_period = cfg.lokiRetention;
              allow_structured_metadata = false;
            };
            compactor = {
              working_directory = "${monitoringDir}/loki/compactor";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };
          };
        };

        # Loki has one HTTP listener. Keep it loopback-only and give remote
        # Alloy a narrowly scoped Tailscale nginx endpoint for push requests.
        services.nginx = {
          enable = true;
          virtualHosts.loki-push = {
            listen = [ { addr = cfg.lokiPushListenAddress; port = cfg.lokiPushPort; } ];
            locations."/loki/api/v1/push" = {
              proxyPass = "http://127.0.0.1:3100";
              extraConfig = ''
                client_max_body_size 16m;
                proxy_set_header Host 127.0.0.1:3100;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              '';
            };
            locations."/".return = "404";
          };
        };
        networking.firewall.interfaces.${cfg.tailscaleInterface}.allowedTCPPorts = [ cfg.lokiPushPort ];

        services.prometheus.exporters.blackbox = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = cfg.blackboxPort;
          configFile = pkgs.writeText "blackbox.yml" ''
            modules:
              http_2xx:
                prober: http
                timeout: 10s
                http:
                  preferred_ip_protocol: ip4
                  follow_redirects: true
                  valid_status_codes: [200, 204]
              http_local:
                prober: http
                timeout: 5s
                http:
                  preferred_ip_protocol: ip4
                  follow_redirects: true
                  valid_status_codes: [200, 204, 401]
          '';
        };

        services.grafana = {
          enable = true;
          dataDir = "${monitoringDir}/grafana";
          settings = lib.recursiveUpdate {
            server = {
              http_addr = "127.0.0.1";
              http_port = 3000;
              domain = cfg.publicHost;
              enforce_domain = true;
              root_url = "https://${cfg.publicHost}/";
            };
            security = {
              admin_user = "admin";
              disable_initial_admin_creation = !cfg.enableOidc;
              cookie_secure = true;
              cookie_samesite = "lax";
              disable_gravatar = true;
            };
            users = {
              allow_sign_up = false;
              allow_org_create = false;
              auto_assign_org = true;
              auto_assign_org_role = "Viewer";
            };
            auth = {
              disable_login_form = !cfg.enableOidc;
              oauth_auto_login = false;
            };
            analytics = {
              reporting_enabled = false;
              check_for_updates = false;
              check_for_plugin_updates = false;
            };
            plugins.enable_alpha = false;
            metrics.enabled = true;
          } (lib.optionalAttrs cfg.enableOidc {
            security = {
              admin_password = grafanaFile cfg.grafanaAdminPasswordFile;
              secret_key = grafanaFile cfg.grafanaSecretKeyFile;
            };
            "auth.generic_oauth" = {
              enabled = true;
              name = "Keycloak";
              allow_sign_up = true;
              client_id = cfg.oidcClientId;
              client_secret = grafanaFile cfg.oidcClientSecretFile;
              scopes = "openid profile email roles";
              auth_url = "https://${cfg.authHost}/realms/${cfg.oidcRealm}/protocol/openid-connect/auth";
              token_url = "https://${cfg.authHost}/realms/${cfg.oidcRealm}/protocol/openid-connect/token";
              api_url = "https://${cfg.authHost}/realms/${cfg.oidcRealm}/protocol/openid-connect/userinfo";
              role_attribute_path = "contains(realm_access.roles[*], 'grafana-admin') && 'Admin' || contains(realm_access.roles[*], 'grafana-viewer') && 'Viewer' || 'None'";
              role_attribute_strict = true;
              allow_assign_grafana_admin = false;
              skip_org_role_sync = false;
              use_pkce = true;
            };
          });
          provision = {
            enable = true;
            datasources.settings.datasources = [
              {
                uid = "prometheus";
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:9090";
                isDefault = true;
                editable = false;
              }
              {
                uid = "loki";
                name = "Loki";
                type = "loki";
                access = "proxy";
                url = "http://127.0.0.1:3100";
                editable = false;
              }
            ];
            dashboards.settings.providers = lib.optionals hasDashboards [
              {
                name = "henhal-monitoring";
                orgId = 1;
                folder = "Henhal Monitoring";
                type = "file";
                disableDeletion = true;
                editable = false;
                options.path = dashboardDir;
              }
            ];
          };
        };

        systemd.services.prometheus.after = [ "loki.service" "alertmanager.service" ];
        systemd.services.grafana.after = [ "prometheus.service" "loki.service" ];
        systemd.services.nginx = {
          after = [ "loki.service" "tailscaled.service" ];
          wants = [ "tailscaled.service" ];
        };

        systemd.services.monitoring-stack-heartbeat = lib.mkIf cfg.enableHeartbeats {
          description = "Notify the independent dead-man service when the monitoring stack is healthy";
          after = ["prometheus.service" "alertmanager.service" "loki.service" "grafana.service" "network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            User = "root";
            ExecStart = "${stackHeartbeat}/bin/monitoring-stack-heartbeat ${cfg.stackHeartbeatUrlFile}";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };
        systemd.timers.monitoring-stack-heartbeat = lib.mkIf cfg.enableHeartbeats {
          description = "Send the monitoring-stack dead-man heartbeat every five minutes";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-* *:0/5:00";
            Persistent = true;
            RandomizedDelaySec = "30s";
          };
        };
      };
    };
}
