# Host-side Prometheus metrics and bounded journal forwarding.
#
# This module intentionally exposes only the Node Exporter scrape endpoint and
# only through the Tailscale firewall interface.  The monitoring hub owns
# Prometheus, Loki, Grafana, alerting, and any public ingress.
{ ... }:
{
  flake.nixosModules.monitoringExporter =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.monitoring.exporter;
      inherit (lib) mkEnableOption mkIf mkOption types;
      textfileDirectory = "/var/lib/prometheus-node-exporter-text-files";
      metric = name: runtimeInputs:
        pkgs.writeShellApplication {
          inherit name runtimeInputs;
          text = builtins.readFile (./metrics + "/${name}.sh");
        };
      nixosHealth = metric "nixos-health" (with pkgs; [ coreutils gawk gnused ]);
      serviceHealth = metric "service-health" (with pkgs; [ coreutils gawk systemd ]);
      storageHealth = metric "storage-health" (with pkgs; [ coreutils jq smartmontools ]);
      backupStatus = metric "backup-status" (with pkgs; [ coreutils jq ]);
      syncthingHealth = metric "syncthing-health" (with pkgs; [ coreutils curl jq libxml2 ]);
      batteryHealth = metric "battery-health" (with pkgs; [ coreutils gawk ]);
      alloyUnitSources = lib.concatMapStringsSep "\n" (unit: let
        label = lib.replaceStrings ["." "-" "@"] ["_" "_" "_"] unit;
      in ''
        loki.source.journal "unit_${label}" {
          max_age       = "24h"
          matches       = "_SYSTEMD_UNIT=${unit}"
          relabel_rules = loki.relabel.journal.rules
          forward_to    = [loki.process.redact.receiver]
        }
      '') cfg.fullJournalUnits;

      mkMetricService =
        {
          name,
          description,
          command,
          interval,
        }:
        {
          systemd.services."henhal-monitoring-${name}" = {
            inherit description;
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              UMask = "0022";
              ExecStart = command;
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ textfileDirectory ];
            };
          };
          systemd.timers."henhal-monitoring-${name}" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2m";
              OnUnitActiveSec = interval;
              Persistent = true;
              Unit = "henhal-monitoring-${name}.service";
            };
          };
        };

      # This filters the full journal down to the bounded labels required by
      # Loki.  It intentionally ships warning-and-higher messages only; the
      # hub can later add a reviewed full-unit pipeline without changing the
      # remote trust boundary.
      alloyJournalConfig = ''
        loki.relabel "journal" {
          rule {
            source_labels = ["__journal__hostname"]
            target_label = "host"
          }
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label = "unit"
          }
          rule {
            source_labels = ["__journal_priority"]
            target_label = "priority"
          }
          rule {
            source_labels = ["__journal_transport"]
            target_label = "transport"
          }
        }

        loki.source.journal "system" {
          max_age       = "24h"
          relabel_rules = loki.relabel.journal.rules
          forward_to    = [loki.process.warning_and_above.receiver]
        }

        loki.process "warning_and_above" {
          stage.match {
            selector            = "{priority=~\"[5-7]\"}"
            action              = "drop"
            drop_counter_reason = "below_warning"
          }
          forward_to = [loki.process.redact.receiver]
        }

        // Defense in depth: journald producers should never log credentials,
        // but redact common authorization and query-secret forms before data
        // leaves the host. Tests use synthetic values, never real secrets.
        loki.process "redact" {
          stage.replace {
            expression = `(?i)(authorization:?\s*(bearer|basic)\s+)[A-Za-z0-9._~+/=-]+`
            replace    = "[REDACTED_AUTHORIZATION]"
          }
          stage.replace {
            expression = `(?i)(token|api[_-]?key|secret|password)=[^&\s]+`
            replace    = "[REDACTED_QUERY_SECRET]"
          }
          forward_to = [loki.write.hub.receiver]
        }

        ${alloyUnitSources}

        loki.write "hub" {
          endpoint {
            url = "http://${cfg.hubHost}:${toString cfg.lokiPort}/loki/api/v1/push"
          }
        }
      '';
    in
    {
      options.my.monitoring.exporter = {
        enable = mkEnableOption "host monitoring exporter and local metric collectors";
        hubHost = mkOption {
          type = types.str;
          default = "hp-server";
          description = "Tailscale MagicDNS hostname of the monitoring hub used by Alloy.";
        };
        tailscaleInterface = mkOption {
          type = types.str;
          default = "tailscale0";
          description = "Firewall interface through which the hub may scrape this exporter.";
        };
        nodeExporterPort = mkOption {
          type = types.port;
          default = 9100;
          description = "Prometheus Node Exporter TCP port, reachable only via tailscaleInterface.";
        };
        lokiPort = mkOption {
          type = types.port;
          default = 3101;
          description = "Tailscale-only Loki push proxy port on the hub, used only as an Alloy destination.";
        };
        enableJournalShipping = mkOption {
          type = types.bool;
          default = true;
          description = "Forward warning-and-higher system journal entries to the hub through Tailscale.";
        };
        enableSmart = mkOption {
          type = types.bool;
          default = true;
          description = "Publish observational SMART/NVMe summary metrics; no tests or repairs are run.";
        };
        enableBattery = mkOption {
          type = types.bool;
          default = false;
          description = "Publish battery capacity metrics when the host has a battery.";
        };
        enableBackupMetrics = mkOption {
          type = types.bool;
          default = false;
          description = "Read HP Restic/staging status files and publish backup metrics.";
        };
        enableSyncthingMetrics = mkOption {
          type = types.bool;
          default = false;
          description = "Read the local Syncthing API and publish Vault/Shared health metrics.";
        };
        syncthingConfigFile = mkOption {
          type = types.str;
          default = "/home/henhal/.config/syncthing/config.xml";
          description = "Local Syncthing configuration from which the root collector reads the API key without emitting it.";
        };
        extraUnits = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "opencloud.service" "keycloak.service" ];
          description = "Reviewed systemd unit allowlist for service-state and restart metrics.";
        };
        fullJournalUnits = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Reviewed units whose complete journal is shipped after credential-pattern redaction; all other units send warning-and-higher entries only.";
        };
      };

      config = mkIf cfg.enable (lib.mkMerge [
        {
          assertions = [
            {
              assertion = config.services.tailscale.enable;
              message = "my.monitoring.exporter requires services.tailscale.enable so metrics are not exposed outside the tailnet.";
            }
            {
              assertion = cfg.hubHost != "";
              message = "my.monitoring.exporter.hubHost must be nonempty when the exporter is enabled.";
            }
          ];

          systemd.tmpfiles.rules = [ "d ${textfileDirectory} 0755 root root -" ];

          services.prometheus.exporters.node = {
            enable = true;
            port = cfg.nodeExporterPort;
            # The NixOS firewall permits this port exclusively on tailscale0;
            # never set openFirewall here, since that creates a global rule.
            listenAddress = "0.0.0.0";
            enabledCollectors = [
              "cpu"
              "diskstats"
              "filesystem"
              "loadavg"
              "meminfo"
              "netdev"
              "processes"
              "systemd"
              "textfile"
              "time"
              "uname"
              "hwmon"
            ];
            extraFlags = [ "--collector.textfile.directory=${textfileDirectory}" ];
          };

          networking.firewall.interfaces.${cfg.tailscaleInterface}.allowedTCPPorts = [ cfg.nodeExporterPort ];

          systemd.services."henhal-monitoring-nixos-health" = {
            description = "Publish NixOS health metrics";
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              UMask = "0022";
              ExecStart = "${nixosHealth}/bin/nixos-health ${textfileDirectory}/nixos-health.prom";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ textfileDirectory ];
            };
          };
          systemd.timers."henhal-monitoring-nixos-health" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2m";
              OnUnitActiveSec = "6h";
              Persistent = true;
              Unit = "henhal-monitoring-nixos-health.service";
            };
          };

          systemd.services."henhal-monitoring-service-health" = {
            description = "Publish reviewed systemd service health metrics";
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              UMask = "0022";
              ExecStart = "${serviceHealth}/bin/service-health ${textfileDirectory}/service-health.prom ${lib.escapeShellArgs cfg.extraUnits}";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ textfileDirectory ];
            };
          };
          systemd.timers."henhal-monitoring-service-health" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2m";
              OnUnitActiveSec = "5m";
              Persistent = true;
              Unit = "henhal-monitoring-service-health.service";
            };
          };
        }
        (mkIf cfg.enableSmart {
          systemd.services."henhal-monitoring-storage-health" = {
            description = "Publish observational storage health metrics";
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              UMask = "0022";
              ExecStart = "${storageHealth}/bin/storage-health ${textfileDirectory}/storage-health.prom";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ textfileDirectory ];
              PrivateDevices = false;
            };
          };
          systemd.timers."henhal-monitoring-storage-health" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "3m";
              OnUnitActiveSec = "15m";
              Persistent = true;
              Unit = "henhal-monitoring-storage-health.service";
            };
          };
        })
        (mkIf cfg.enableBattery {
          systemd.services."henhal-monitoring-battery-health" = {
            description = "Publish battery capacity health metrics";
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              UMask = "0022";
              ExecStart = "${batteryHealth}/bin/battery-health ${textfileDirectory}/battery-health.prom";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ textfileDirectory ];
            };
          };
          systemd.timers."henhal-monitoring-battery-health" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "3m";
              OnUnitActiveSec = "5m";
              Persistent = true;
              Unit = "henhal-monitoring-battery-health.service";
            };
          };
        })
        (mkIf cfg.enableBackupMetrics {
          systemd.services."henhal-monitoring-backup-status" = {
            description = "Publish HP Restic and staged source metrics";
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              UMask = "0022";
              ExecStart = "${backupStatus}/bin/backup-status ${textfileDirectory}/backup-status.prom";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectHome = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ textfileDirectory ];
            };
          };
          systemd.timers."henhal-monitoring-backup-status" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "3m";
              OnUnitActiveSec = "5m";
              Persistent = true;
              Unit = "henhal-monitoring-backup-status.service";
            };
          };
        })
        (mkIf cfg.enableSyncthingMetrics {
          systemd.services."henhal-monitoring-syncthing-health" = {
            description = "Publish Syncthing Vault and Shared metrics";
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              Group = "root";
              UMask = "0022";
              Environment = [ "HENHAL_SYNCTHING_CONFIG=${cfg.syncthingConfigFile}" ];
              ExecStart = "${syncthingHealth}/bin/syncthing-health ${textfileDirectory}/syncthing-health.prom";
              NoNewPrivileges = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ReadWritePaths = [ textfileDirectory ];
            };
          };
          systemd.timers."henhal-monitoring-syncthing-health" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "3m";
              OnUnitActiveSec = "5m";
              Persistent = true;
              Unit = "henhal-monitoring-syncthing-health.service";
            };
          };
        })
        (mkIf cfg.enableJournalShipping {
          services.alloy = {
            enable = true;
            extraFlags = [ "--server.http.listen-addr=127.0.0.1:12345" "--disable-reporting" ];
          };
          environment.etc."alloy/monitoring-journal.alloy".text = alloyJournalConfig;
        })
      ]);
    };
}
