# HP's encrypted off-site Restic job and the auxiliary consistent sources.
{ ... }:
{
  flake.nixosModules.hpResticS3 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.hpBackup;
      sourceLock = "/var/lib/hp-backup/source.lock";
      statusDir = "/var/lib/restic-status";
      # Built-in Restic sources. Do not repeat these in `my.hpBackup.extraPaths`:
      # - /run/opencloud-backup/current: complete stopped-service OpenCloud unit
      # - /var/lib/opencloud-identity-backup/latest: Keycloak/OpenLDAP export
      # - /var/lib/{vault,shared}-backup/latest: staged Syncthing directories
      # - /var/lib/github-mirrors/current and /var/lib/hermes-backup/latest
      # `extraPaths` is only for ordinary HP-local files that can be read live.
      backupPaths = [
        "/run/opencloud-backup/current"
        "/var/lib/opencloud-identity-backup/latest"
        "/var/lib/vault-backup/latest"
        "/var/lib/shared-backup/latest"
        "/var/lib/github-mirrors/current"
        "/var/lib/hermes-backup/latest"
      ] ++ cfg.extraPaths;
      backupPathArgs = lib.concatMapStringsSep " " lib.escapeShellArg backupPaths;
      sourceStatus = pkgs.writeShellApplication {
        name = "hp-backup-source-status";
        runtimeInputs = with pkgs; [
          coreutils
          jq
        ];
        text = ''
          mkdir -p ${statusDir}
          now="$(date +%s)"
          result=healthy
          details='[]'
          for name in opencloud-source opencloud-identity vault shared hermes github-mirror; do
            if [[ "$name" == github-mirror ]]; then
              file=/var/lib/github-mirrors/status.json
            else
              file="${statusDir}/$name.json"
            fi
            if [[ ! -f "$file" ]]; then
              result=degraded
              details="$(jq --arg name "$name" '. + [{source: $name, result: "missing"}]' <<<"$details")"
              continue
            fi
            timestamp="$(jq -r '.timestamp // .createdAt // empty' "$file")"
            age=999999
            [[ -z "$timestamp" ]] || age=$(( now - $(date --date="$timestamp" +%s 2>/dev/null || echo 0) ))
            state="$(jq -r '.result // "healthy"' "$file")"
            if [[ "$state" != healthy || "$age" -gt 129600 ]]; then
              result=degraded
            fi
            details="$(jq --arg name "$name" --arg result "$state" --argjson age "$age" '. + [{source: $name, result: $result, ageSeconds: $age}]' <<<"$details")"
          done
          jq -n --arg timestamp "$(date --iso-8601=seconds)" --arg result "$result" \
            --argjson sources "$details" '{timestamp: $timestamp, result: $result, sources: $sources}' \
            >${statusDir}/last-source-status.tmp
          mv -f ${statusDir}/last-source-status.tmp ${statusDir}/last-source-status
        '';
      };
      identityExport = pkgs.writeShellApplication {
        name = "opencloud-identity-export";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          openldap
          postgresql
          util-linux
        ];
        text = ''
          set -o pipefail
          root=/var/lib/opencloud-identity-backup
          status=${statusDir}/opencloud-identity.json
          candidate="$(mktemp -d "$root/candidate.XXXXXX")"
          opencloud_stopped=0
          ldap_stopped=0
          finish() {
            if (( ldap_stopped )); then
              systemctl start openldap.service || true
            fi
            if (( opencloud_stopped )); then
              systemctl start opencloud.service || true
            fi
            rm -rf "$candidate"
          }
          trap finish EXIT
          fail() {
            jq -n --arg timestamp "$(date --iso-8601=seconds)" --arg detail "$1" \
              '{timestamp: $timestamp, result: "degraded", detail: $detail}' >"$status.tmp"
            mv -f "$status.tmp" "$status"
            exit 0
          }
          exec 9>${sourceLock}; flock -x 9 || fail "could not acquire source lock"
          # The root-owned staging directory must remain private.  Have
          # postgres read the database but let this root shell create the
          # resulting dump file.
          runuser -u postgres -- ${pkgs.postgresql}/bin/pg_dump --format=custom keycloak >"$candidate/keycloak.pg.dump" \
            || fail "Keycloak PostgreSQL logical export failed"
          ${pkgs.postgresql}/bin/pg_restore --list "$candidate/keycloak.pg.dump" >/dev/null \
            || fail "Keycloak PostgreSQL export validation failed"

          # The Keycloak database and OpenLDAP directory are one identity
          # recovery unit. Stop their sole writer before creating a logical LDIF
          # export; copying the live LMDB files would not be a valid restore.
          if systemctl is-active --quiet opencloud.service; then
            systemctl stop opencloud.service || fail "could not stop OpenCloud for the LDAP export"
            opencloud_stopped=1
          fi
          if systemctl is-active --quiet openldap.service; then
            systemctl stop openldap.service || fail "could not stop OpenLDAP for its logical export"
            ldap_stopped=1
          fi
          ${pkgs.openldap}/bin/slapcat -F /etc/openldap/slapd.d \
            -b dc=opencloud,dc=eu -l "$candidate/opencloud-ldap.ldif" \
            || fail "OpenLDAP logical export failed"
          [[ -s "$candidate/opencloud-ldap.ldif" ]] || fail "OpenLDAP logical export was empty"
          if (( ldap_stopped )); then
            systemctl start openldap.service || fail "could not restart OpenLDAP after export"
            ldap_stopped=0
          fi
          if (( opencloud_stopped )); then
            systemctl start opencloud.service || fail "could not restart OpenCloud after LDAP export"
            opencloud_stopped=0
          fi
          jq -n --arg timestamp "$(date --iso-8601=seconds)" \
            '{timestamp: $timestamp, result: "healthy", keycloak: "pg_dump custom", opencloudLdap: "slapcat LDIF", realmConfiguration: "contained in logical database export"}' \
            >"$candidate/manifest.json"
          rm -rf "$root/previous"; [[ ! -d "$root/latest" ]] || mv "$root/latest" "$root/previous"
          mv "$candidate" "$root/latest"; candidate=""
          cp "$root/latest/manifest.json" "$status"
        '';
      };
      mkSyncthingStage = {
        name,
        folderId,
        source,
      }:
        pkgs.writeShellApplication {
          name = "syncthing-${name}-backup";
          runtimeInputs = with pkgs; [
            coreutils
            curl
            jq
            libxml2
            rsync
            util-linux
          ];
          text = ''
            set -o pipefail
            root=/var/lib/${name}-backup
            status=${statusDir}/${name}.json
            source=${lib.escapeShellArg source}
            configFile=/home/henhal/.config/syncthing/config.xml
            syncthing_stopped=0
            cleanup() {
              if (( syncthing_stopped )); then
                systemctl start syncthing.service || true
              fi
            }
            trap cleanup EXIT
            fail() {
              jq -n --arg timestamp "$(date --iso-8601=seconds)" --arg detail "$1" \
                '{timestamp: $timestamp, result: "degraded", detail: $detail}' >"$status.tmp"
              mv -f "$status.tmp" "$status"
              exit 0
            }
            [[ -d "$source" ]] || fail "Syncthing ${name} directory is missing: $source"
            [[ -r "$configFile" ]] || fail "Syncthing configuration is unavailable: $configFile"
            if ! apiKey="$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "$configFile" 2>/dev/null)"; then
              fail "could not parse the Syncthing API key from $configFile"
            fi
            [[ -n "$apiKey" ]] || fail "Syncthing API key is unavailable in $configFile"
            exec 9>${sourceLock}; flock -x 9 || fail "could not acquire source lock"
            # Scan and verify twice so a folder that is actively changing is
            # retained from the previous validated stage instead of copied live.
            for _ in 1 2; do
              curl --fail --silent --show-error -X POST -H "X-API-Key: $apiKey" \
                'http://127.0.0.1:8384/rest/db/scan?folder=${folderId}' >/dev/null || fail "could not request Syncthing ${name} scan"
              state="$(curl --fail --silent --show-error -H "X-API-Key: $apiKey" \
                'http://127.0.0.1:8384/rest/db/status?folder=${folderId}')" || fail "could not read Syncthing ${name} status"
              jq -e '.state == "idle" and .needTotalItems == 0 and .pullErrors == 0' <<<"$state" >/dev/null \
                || fail "Syncthing ${name} is not idle and healthy"
              sleep 2
            done
            candidate="$(mktemp -d "$root/candidate.XXXXXX")"
            if ! systemctl stop syncthing.service || systemctl is-active --quiet syncthing.service; then
              rm -rf "$candidate"; fail "could not stop Syncthing for the ${name} consistency boundary"
            fi
            syncthing_stopped=1
            if ! rsync -aHAX --numeric-ids "$source/" "$candidate/contents/"; then
              rm -rf "$candidate"; fail "Syncthing ${name} copy failed"
            fi
            if ! systemctl start syncthing.service; then
              rm -rf "$candidate"; fail "could not restart Syncthing after ${name} staging"
            fi
            syncthing_stopped=0
            jq -n --arg timestamp "$(date --iso-8601=seconds)" --arg source "$source" \
              '{timestamp: $timestamp, result: "healthy", source: $source, method: "stopped-service rsync -aHAX"}' >"$candidate/manifest.json"
            rm -rf "$root/previous"; [[ ! -d "$root/latest" ]] || mv "$root/latest" "$root/previous"
            mv "$candidate" "$root/latest"
            cp "$root/latest/manifest.json" "$status"
          '';
        };
      vaultStage = mkSyncthingStage {
        name = "vault";
        folderId = "vault";
        source = "/home/henhal/Vault";
      };
      sharedStage = mkSyncthingStage {
        name = "shared";
        folderId = "shared";
        source = "/home/henhal/Shared";
      };
      hermesExport = pkgs.writeShellApplication {
        name = "hermes-backup-export";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          util-linux
        ];
        text = ''
          root=/var/lib/hermes-backup
          status=${statusDir}/hermes.json
          fail() {
            jq -n --arg timestamp "$(date --iso-8601=seconds)" --arg detail "$1" \
              '{timestamp: $timestamp, result: "degraded", detail: $detail}' >"$status.tmp"
            mv -f "$status.tmp" "$status"
            exit 0
          }
          [[ -n ${
            lib.escapeShellArg (cfg.hermesExportCommand or "")
          } ]] || fail "no reviewed Hermes-native export command is configured"
          exec 9>${sourceLock}; flock -x 9 || fail "could not acquire source lock"
          candidate="$(mktemp -d "$root/candidate.XXXXXX")"
          if ! HERMES_EXPORT_DEST="$candidate" ${pkgs.bash}/bin/bash -c ${
            lib.escapeShellArg (cfg.hermesExportCommand or "")
          }; then
            rm -rf "$candidate"; fail "Hermes export command failed"
          fi
          [[ -n "$(find "$candidate" -mindepth 1 -print -quit)" ]] || { rm -rf "$candidate"; fail "Hermes export was empty"; }
          jq -n --arg timestamp "$(date --iso-8601=seconds)" \
            '{timestamp: $timestamp, result: "healthy", method: "reviewed native export"}' >"$candidate/manifest.json"
          rm -rf "$root/previous"; [[ ! -d "$root/latest" ]] || mv "$root/latest" "$root/previous"
          mv "$candidate" "$root/latest"
          cp "$root/latest/manifest.json" "$status"
        '';
      };
      resticRun = pkgs.writeShellApplication {
        name = "restic-hp-offsite-run";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
          restic
          util-linux
        ];
        text = ''
          ${pkgs.util-linux}/bin/flock -s ${sourceLock} ${pkgs.restic}/bin/restic backup \
            ${backupPathArgs}
          mkdir -p ${statusDir}
          date --iso-8601=seconds >${statusDir}/last-success.tmp
          mv -f ${statusDir}/last-success.tmp ${statusDir}/last-success

          ${lib.optionalString cfg.enableSuccessHeartbeat ''
            heartbeat_status=${statusDir}/last-backup-heartbeat-status.json
            source_state="$(${pkgs.jq}/bin/jq -r '.result // "degraded"' ${statusDir}/last-source-status 2>/dev/null || printf degraded)"
            heartbeat_result=skipped
            heartbeat_detail="source status was not healthy"
            if [[ "$source_state" == healthy ]]; then
              heartbeat_url="$(tr -d '\r\n' <${lib.escapeShellArg (if cfg.successHeartbeatUrlFile == null then "/run/secrets/missing-backup-heartbeat" else cfg.successHeartbeatUrlFile)})"
              if [[ "$heartbeat_url" == https://* && "$heartbeat_url" != *'"'* ]]; then
                escaped="''${heartbeat_url//\\/\\\\}"
                escaped="''${escaped//\"/\\\"}"
                if printf 'url = "%s"\nfail\nsilent\nlocation\nconnect-timeout = 10\nmax-time = 20\noutput = /dev/null\n' "$escaped" \
                  | curl --config - >/dev/null 2>&1; then
                  heartbeat_result=healthy
                  heartbeat_detail="delivery succeeded"
                  date --iso-8601=seconds >${statusDir}/last-backup-heartbeat-success.tmp
                  mv -f ${statusDir}/last-backup-heartbeat-success.tmp ${statusDir}/last-backup-heartbeat-success
                else
                  heartbeat_result=degraded
                  heartbeat_detail="delivery failed"
                fi
              else
                heartbeat_result=degraded
                heartbeat_detail="URL file was invalid"
              fi
            fi
            jq -n --arg timestamp "$(date --iso-8601=seconds)" \
              --arg result "$heartbeat_result" --arg detail "$heartbeat_detail" \
              '{timestamp: $timestamp, result: $result, detail: $detail}' >"$heartbeat_status.tmp"
            mv -f "$heartbeat_status.tmp" "$heartbeat_status"
          ''}
        '';
      };
      resticCheck = pkgs.writeShellApplication {
        name = "restic-hp-offsite-check";
        runtimeInputs = with pkgs; [coreutils restic];
        text = ''
          # A sampled content check is observational and bounded. It neither
          # forgets snapshots nor prunes repository data.
          restic check --read-data-subset=5%
          mkdir -p ${statusDir}
          date --iso-8601=seconds >${statusDir}/last-check-success.tmp
          mv -f ${statusDir}/last-check-success.tmp ${statusDir}/last-check-success
        '';
      };
    in
    {
      options.my.hpBackup = {
        enable = lib.mkEnableOption "HP's encrypted S3 Restic backup";
        extraPaths = lib.mkOption {
          type = lib.types.listOf (lib.types.strMatching "^/.*");
          default = [ ];
          example = [
            "/home/henhal/Documents"
            "/home/henhal/Pictures"
          ];
          description = "Additional absolute paths for Restic to back up. Use only ordinary HP-local files that can be read live. Do not add OpenCloud, Vault, Shared, identity, GitHub mirror, or Hermes paths: those are built-in staged/exported sources.";
        };
        hermesExportCommand = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
          description = "Reviewed Hermes-native export command; no live state is copied when this is unset.";
        };
        enableSuccessHeartbeat = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Send an external pulse only after Restic succeeds and every staged source reports healthy.";
        };
        successHeartbeatUrlFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Root-readable runtime file containing the external backup-success heartbeat URL.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.opencloud.enable;
            message = "my.hpBackup requires my.opencloud.enable.";
          }
          {
            assertion = config.my.opencloudConsistentSource.enable;
            message = "my.hpBackup requires my.opencloudConsistentSource.enable.";
          }
          {
            assertion = config.my.githubMirror.enable;
            message = "my.hpBackup requires my.githubMirror.enable.";
          }
          {
            assertion = !cfg.enableSuccessHeartbeat || cfg.successHeartbeatUrlFile != null;
            message = "my.hpBackup.successHeartbeatUrlFile is required when the success heartbeat is enabled.";
          }
        ];

        sops.secrets.RESTIC_REPOSITORY_PASSWORD = {
          sopsFile = ../../../secrets/hp-backup.yaml;
          owner = "root";
          group = "root";
          mode = "0400";
        };
        sops.secrets.RESTIC_AWS_ACCESS_KEY_ID = {
          sopsFile = ../../../secrets/hp-backup.yaml;
          mode = "0400";
        };
        sops.secrets.RESTIC_AWS_SECRET_ACCESS_KEY = {
          sopsFile = ../../../secrets/hp-backup.yaml;
          mode = "0400";
        };
        sops.secrets.RESTIC_AWS_DEFAULT_REGION = {
          sopsFile = ../../../secrets/hp-backup.yaml;
          mode = "0400";
        };
        sops.secrets.RESTIC_REPOSITORY = {
          sopsFile = ../../../secrets/hp-backup.yaml;
          mode = "0400";
        };
        sops.templates."restic-s3-env" = {
          owner = "root";
          group = "root";
          mode = "0400";
          content = ''
            AWS_ACCESS_KEY_ID=${config.sops.placeholder.RESTIC_AWS_ACCESS_KEY_ID}
            AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.RESTIC_AWS_SECRET_ACCESS_KEY}
            AWS_DEFAULT_REGION=${config.sops.placeholder.RESTIC_AWS_DEFAULT_REGION}
            RESTIC_REPOSITORY=${config.sops.placeholder.RESTIC_REPOSITORY}
          '';
        };

        systemd.tmpfiles.settings."10-hp-backup" = {
          "${statusDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/opencloud-identity-backup".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/opencloud-identity-backup/latest".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/vault-backup".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/vault-backup/latest".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/shared-backup".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/shared-backup/latest".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/hermes-backup".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "/var/lib/hermes-backup/latest".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
        };

        systemd.services.opencloud-identity-export = {
          description = "Create a validated logical Keycloak recovery export";
          after = [ "postgresql.target" ];
          serviceConfig.Type = "oneshot";
          script = "exec ${identityExport}/bin/opencloud-identity-export";
        };
        systemd.services.syncthing-vault-backup = {
          description = "Create a consistent staged HP Syncthing vault source";
          after = [ "syncthing.service" ];
          serviceConfig.Type = "oneshot";
          script = "exec ${vaultStage}/bin/syncthing-vault-backup";
        };
        systemd.services.syncthing-shared-backup = {
          description = "Create a consistent staged HP Syncthing Shared source";
          after = [ "syncthing.service" "syncthing-vault-backup.service" ];
          serviceConfig.Type = "oneshot";
          script = "exec ${sharedStage}/bin/syncthing-shared-backup";
        };
        systemd.services.hermes-export = {
          description = "Create a validated Hermes export when configured";
          serviceConfig.Type = "oneshot";
          script = "exec ${hermesExport}/bin/hermes-backup-export";
        };

        services.restic.backups.hp-offsite = {
          user = "root";
          environmentFile = config.sops.templates."restic-s3-env".path;
          passwordFile = config.sops.secrets.RESTIC_REPOSITORY_PASSWORD.path;
          # On the first run, create the encrypted Restic repository at the
          # configured R2 prefix. Subsequent runs only verify its config.
          initialize = true;
          paths = [ "/run/opencloud-backup/current" ];
          pruneOpts = [ ];
          timerConfig = {
            OnCalendar = "*-*-* 03:00:00";
            Persistent = true;
          };
          backupPrepareCommand = ''
            ${config.my.opencloudConsistentSource.prepare}/bin/opencloud-backup-prepare
            ${sourceStatus}/bin/hp-backup-source-status
          '';
          backupCleanupCommand = "${config.my.opencloudConsistentSource.cleanup}/bin/opencloud-backup-cleanup";
        };

        systemd.services.restic-backups-hp-offsite = {
          after = [
            "github-mirror.service"
            "opencloud-identity-export.service"
            "syncthing-vault-backup.service"
            "syncthing-shared-backup.service"
            "hermes-export.service"
          ];
          wants = [
            "github-mirror.service"
            "opencloud-identity-export.service"
            "syncthing-vault-backup.service"
            "syncthing-shared-backup.service"
            "hermes-export.service"
          ];
          unitConfig = {
            RequiresMountsFor = "/srv/opencloud";
            ConditionPathIsMountPoint = "/srv/opencloud";
          };
          serviceConfig.ExecStart = lib.mkForce [ "${resticRun}/bin/restic-hp-offsite-run" ];
        };

        systemd.services.restic-hp-offsite-check = {
          description = "Run a sampled integrity check of the HP Restic repository";
          after = ["network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.sops.templates."restic-s3-env".path;
            Environment = [
              "RESTIC_PASSWORD_FILE=${config.sops.secrets.RESTIC_REPOSITORY_PASSWORD.path}"
              "RESTIC_CACHE_DIR=/var/cache/restic-hp-offsite-check"
            ];
            ExecStart = "${resticCheck}/bin/restic-hp-offsite-check";
            User = "root";
            CacheDirectory = "restic-hp-offsite-check";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadWritePaths = [statusDir];
          };
        };
        systemd.timers.restic-hp-offsite-check = {
          description = "Monthly sampled Restic repository integrity check";
          wantedBy = ["timers.target"];
          timerConfig = {
            OnCalendar = "*-*-01 04:30:00";
            Persistent = true;
            RandomizedDelaySec = "30m";
          };
        };
      };
    };
}
