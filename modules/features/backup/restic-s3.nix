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
      backupPaths = [
        "/run/opencloud-backup/current"
        "/var/lib/opencloud-identity-backup/latest"
        "/var/lib/vault-backup/latest"
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
          for name in opencloud-source opencloud-identity vault hermes github-mirror; do
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
          runuser -u postgres -- ${pkgs.postgresql}/bin/pg_dump --format=custom --file="$candidate/keycloak.pg.dump" keycloak \
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
      vaultStage = pkgs.writeShellApplication {
        name = "syncthing-vault-backup";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
          rsync
          util-linux
        ];
        text = ''
          set -o pipefail
          root=/var/lib/vault-backup
          status=${statusDir}/vault.json
          source=/home/henhal/Vault
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
          apiKey="$(sed -n 's:.*<apikey>\\(.*\\)</apikey>.*:\\1:p' "$configFile" | head -n1)"
          [[ -n "$apiKey" && -d "$source" ]] || fail "Syncthing vault source or API credential is unavailable"
          exec 9>${sourceLock}; flock -x 9 || fail "could not acquire source lock"
          # Run the scan/status check twice; the value itself is intentionally
          # unused, so use the conventional underscore variable.
          for _ in 1 2; do
            curl --fail --silent --show-error -X POST -H "X-API-Key: $apiKey" \
              'http://127.0.0.1:8384/rest/db/scan?folder=vault' >/dev/null || fail "could not request Syncthing vault scan"
            state="$(curl --fail --silent --show-error -H "X-API-Key: $apiKey" \
              'http://127.0.0.1:8384/rest/db/status?folder=vault')" || fail "could not read Syncthing vault status"
            jq -e '.state == "idle" and .needTotalItems == 0 and .pullErrors == 0' <<<"$state" >/dev/null \
              || fail "Syncthing vault is not idle and healthy"
            sleep 2
          done
          candidate="$(mktemp -d "$root/candidate.XXXXXX")"
          if ! systemctl stop syncthing.service || systemctl is-active --quiet syncthing.service; then
            rm -rf "$candidate"; fail "could not stop Syncthing for the vault consistency boundary"
          fi
          syncthing_stopped=1
          if ! rsync -aHAX --numeric-ids "$source/" "$candidate/contents/"; then
            rm -rf "$candidate"; fail "vault copy failed"
          fi
          if ! systemctl start syncthing.service; then
            rm -rf "$candidate"; fail "could not restart Syncthing after vault staging"
          fi
          syncthing_stopped=0
          jq -n --arg timestamp "$(date --iso-8601=seconds)" --arg source "$source" \
            '{timestamp: $timestamp, result: "healthy", source: $source, method: "stopped-service rsync -aHAX"}' >"$candidate/manifest.json"
          rm -rf "$root/previous"; [[ ! -d "$root/latest" ]] || mv "$root/latest" "$root/previous"
          mv "$candidate" "$root/latest"
          cp "$root/latest/manifest.json" "$status"
        '';
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
          restic
          util-linux
        ];
        text = ''
          ${pkgs.util-linux}/bin/flock -s ${sourceLock} ${pkgs.restic}/bin/restic backup \
            ${backupPathArgs}
          mkdir -p ${statusDir}
          date --iso-8601=seconds >${statusDir}/last-success.tmp
          mv -f ${statusDir}/last-success.tmp ${statusDir}/last-success
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
          description = "Additional absolute paths for Restic to back up. Use only ordinary files that can be read live; application data needing a consistency boundary has a dedicated staged source.";
        };
        hermesExportCommand = lib.mkOption {
          type = lib.types.nullOr lib.types.lines;
          default = null;
          description = "Reviewed Hermes-native export command; no live state is copied when this is unset.";
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
            OnCalendar = "*-*-* 03,15:00:00";
            Persistent = true;
            RandomizedDelaySec = "1h";
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
            "hermes-export.service"
          ];
          wants = [
            "github-mirror.service"
            "opencloud-identity-export.service"
            "syncthing-vault-backup.service"
            "hermes-export.service"
          ];
          unitConfig = {
            RequiresMountsFor = "/srv/opencloud";
            ConditionPathIsMountPoint = "/srv/opencloud";
          };
          serviceConfig.ExecStart = lib.mkForce [ "${resticRun}/bin/restic-hp-offsite-run" ];
        };
      };
    };
}
