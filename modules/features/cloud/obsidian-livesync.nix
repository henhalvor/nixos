# Self-hosted LiveSync for Obsidian: CouchDB on the HP T7, published through
# the existing Cloudflare tunnel, plus a headless LiveSync CLI daemon that keeps
# HP's plain ~/Vault mirror in sync. See docs/OBSIDIAN.md.
{ ... }:
{
  flake.nixosModules.obsidianLivesync =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.obsidianLivesync;
      couchCfg = config.services.couchdb;
      secretsFile = ../../../secrets/obsidian-livesync.yaml;
      origin = "http://127.0.0.1:${toString cfg.port}";
      adminUser = "admin";
      cliState = "/var/lib/obsidian-livesync-cli";
      cliService = "docker-obsidian-livesync-cli";
      cliMarker = "${cliState}/initialised";
      cliSettings = "${cliState}/data/.livesync/settings.json";

      # Pin the CLI image to the plug-in release used on the clients. The
      # daemon and Obsidian share the same Commonlib, so upgrade them together.
      cliImage = pkgs.dockerTools.pullImage {
        imageName = "ghcr.io/vrtmrz/livesync-cli";
        imageDigest = "sha256:30207bae80635f4a803cd6c072e3934e6c0c611235039661b0630aeb323cb53a";
        hash = "sha256-Lsabhdp31s2JB2i50p/NZkyVzUVRE88hltVGA+8Css4=";
        finalImageName = "ghcr.io/vrtmrz/livesync-cli";
        finalImageTag = "1.0.46-cli";
      };
      cliImageRef = "ghcr.io/vrtmrz/livesync-cli:1.0.46-cli";

      # Shared by the daemon and the one-time initialisation helper. The CLI
      # reaches CouchDB on loopback, so it never depends on the tunnel or
      # Cloudflare Access.
      cliRunOptions = [
        "--network=host"
        "--user=${toString cfg.vaultUid}:${toString cfg.vaultGid}"
        "--read-only"
        "--tmpfs=/tmp"
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges"
        "--env=HOME=/data"
        "--volume=${cliState}/data:/data"
        "--volume=${cfg.vaultPath}:/vault"
      ];

      couchCurl = pkgs.writeShellApplication {
        name = "obsidian-livesync-couch-curl";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          # Usage: obsidian-livesync-couch-curl <user> <password-file> <curl args...>
          # Credentials are passed through a pipe so they never appear in argv;
          # stdin stays free for request bodies (--data-binary @-).
          user="$1"
          password="$(<"$2")"
          shift 2
          curl --config <(printf 'user = "%s:%s"\n' "$user" "$password") --silent --show-error "$@"
        '';
      };

      provision = pkgs.writeShellApplication {
        name = "couchdb-livesync-provision";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
          couchCurl
        ];
        text = ''
          base=${lib.escapeShellArg origin}
          db=${lib.escapeShellArg cfg.database}
          user=${lib.escapeShellArg cfg.couchUser}
          adminPassword=${config.sops.secrets.COUCHDB_ADMIN_PASSWORD.path}
          userPassword=${config.sops.secrets.LIVESYNC_COUCHDB_PASSWORD.path}

          admin() { obsidian-livesync-couch-curl ${adminUser} "$adminPassword" "$@"; }
          status() { curl --silent --output /dev/null --write-out '%{http_code}' "$@"; }
          expect() {
            local want="$1" got="$2" what="$3"
            [[ "$got" == "$want" ]] || { echo "$what: expected HTTP $want, got $got" >&2; exit 1; }
          }

          # /_up answers before the configured admins are accepted, so wait
          # for an authenticated request rather than only the health check.
          adminReady() { admin --output /dev/null --write-out '%{http_code}' "$base/_all_dbs" || true; }
          for _ in $(seq 60); do
            [[ "$(adminReady)" == 200 ]] && break
            sleep 1
          done
          expect 200 "$(adminReady)" "CouchDB admin readiness"

          # single_node creates the system databases; this only verifies them.
          for system_db in _users _replicator "$db"; do
            code="$(admin --output /dev/null --write-out '%{http_code}' -X PUT "$base/$system_db")"
            [[ "$code" == 201 || "$code" == 412 ]] || { echo "could not create $system_db: HTTP $code" >&2; exit 1; }
          done

          # Explicit members, so the database is never readable by any other
          # account that might be created later.
          jq -n --arg name "$user" \
            '{admins: {names: [$name], roles: []}, members: {names: [$name], roles: []}}' \
            | admin --fail -X PUT -H 'Content-Type: application/json' --data-binary @- "$base/$db/_security" >/dev/null

          # Refuse to report success unless anonymous access is rejected.
          expect 401 "$(status "$base/")" "anonymous server access"
          expect 401 "$(status "$base/$db")" "anonymous database access"
          expect 200 "$(obsidian-livesync-couch-curl "$user" "$userPassword" --output /dev/null --write-out '%{http_code}' "$base/$db")" \
            "LiveSync user database access"
          echo "CouchDB provisioning for $db completed."
        '';
      };

      # Enforce the connection and encryption fields on top of whatever the
      # CLI has persisted itself (for example its local database suffix).
      cliSettingsApply = pkgs.writeShellApplication {
        name = "obsidian-livesync-cli-settings";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          config.virtualisation.docker.package
        ];
        text = ''
          settings=${cliSettings}
          [[ "$(id -u ${cfg.vaultOwner})" == ${toString cfg.vaultUid} && "$(id -g ${cfg.vaultOwner})" == ${toString cfg.vaultGid} ]] \
            || { echo "my.obsidianLivesync.vaultUid/vaultGid do not match ${cfg.vaultOwner}" >&2; exit 1; }
          install -d -m 0700 -o ${toString cfg.vaultUid} -g ${toString cfg.vaultGid} "$(dirname "$settings")"
          if [[ ! -s "$settings" ]]; then
            docker image inspect ${cliImageRef} >/dev/null 2>&1 || docker load -i ${cliImage}
            docker run --rm ${lib.escapeShellArgs cliRunOptions} ${cliImageRef} \
              init-settings /data/.livesync/settings.json
          fi
          tmp="$(mktemp "$settings.XXXXXX")"
          jq \
            --arg uri ${lib.escapeShellArg origin} \
            --arg user ${lib.escapeShellArg cfg.couchUser} \
            --arg db ${lib.escapeShellArg cfg.database} \
            --rawfile password ${config.sops.secrets.LIVESYNC_COUCHDB_PASSWORD.path} \
            --rawfile passphrase ${config.sops.secrets.LIVESYNC_E2EE_PASSPHRASE.path} \
            '. * {
              couchDB_URI: $uri,
              couchDB_USER: $user,
              couchDB_PASSWORD: ($password | rtrimstr("\n")),
              couchDB_DBNAME: $db,
              couchDB_CustomHeaders: "",
              encrypt: true,
              passphrase: ($passphrase | rtrimstr("\n")),
              usePathObfuscation: true,
              syncInternalFiles: false,
              usePluginSync: false,
              liveSync: true,
              isConfigured: true
            }' "$settings" >"$tmp"
          chown ${toString cfg.vaultUid}:${toString cfg.vaultGid} "$tmp"
          chmod 0600 "$tmp"
          mv -f "$tmp" "$settings"
        '';
      };

      # Manual, one-time: replaces HP's local LiveSync database with the
      # server state and writes it into an empty Vault directory.
      cliInit = pkgs.writeShellApplication {
        name = "obsidian-livesync-hp-init";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          systemd
          config.virtualisation.docker.package
          cliSettingsApply
        ];
        text = ''
          vault=${lib.escapeShellArg cfg.vaultPath}
          [[ "$EUID" == 0 ]] || { echo "Run with sudo." >&2; exit 1; }
          [[ ! -e ${cliMarker} ]] || { echo "Already initialised (${cliMarker} exists)." >&2; exit 1; }
          systemctl is-active --quiet couchdb-livesync-provision.service \
            || { echo "couchdb-livesync-provision.service has not completed." >&2; exit 1; }
          [[ -d "$vault" && -z "$(find "$vault" -mindepth 1 -print -quit)" ]] \
            || { echo "$vault must exist and be empty. Move any old copy aside first." >&2; exit 1; }

          systemctl stop ${cliService}.service || true
          docker image inspect ${cliImageRef} >/dev/null 2>&1 || docker load -i ${cliImage}
          obsidian-livesync-cli-settings
          docker run --rm ${lib.escapeShellArgs cliRunOptions} ${cliImageRef} \
            --vault /vault fetch --force
          touch ${cliMarker}
          systemctl start ${cliService}.service
          echo "HP Vault initialised; ${cliService}.service is now running."
        '';
      };
    in
    {
      options.my.obsidianLivesync = {
        enable = lib.mkEnableOption "Self-hosted LiveSync CouchDB and HP's headless Vault mirror";

        host = lib.mkOption {
          type = lib.types.str;
          example = "obsidian-livesync.example.com";
          description = "Public hostname routed through the Cloudflare tunnel to CouchDB.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 5984;
          readOnly = true;
          description = "Loopback-only CouchDB listener.";
        };

        storageRoot = lib.mkOption {
          type = lib.types.strMatching "^/srv/opencloud(/.*)?$";
          default = "/srv/opencloud/couchdb";
          readOnly = true;
          description = "CouchDB data root on the mounted OpenCloud T7 filesystem.";
        };

        database = lib.mkOption {
          type = lib.types.str;
          default = "obsidian";
          readOnly = true;
          description = "LiveSync database name.";
        };

        couchUser = lib.mkOption {
          type = lib.types.str;
          default = "obsidian";
          readOnly = true;
          description = "CouchDB server-admin account shared by the LiveSync clients and HP's CLI daemon.";
        };

        vaultPath = lib.mkOption {
          type = lib.types.str;
          default = "/home/henhal/Vault";
          description = "HP's plain-file Vault mirror maintained by the LiveSync CLI daemon.";
        };

        vaultOwner = lib.mkOption {
          type = lib.types.str;
          default = "henhal";
          description = "Owner of the Vault mirror.";
        };

        vaultUid = lib.mkOption {
          type = lib.types.int;
          default = 1000;
          description = "Numeric uid the CLI container writes the Vault as; checked against vaultOwner at start.";
        };

        vaultGid = lib.mkOption {
          type = lib.types.int;
          default = 100;
          description = "Numeric gid the CLI container writes the Vault as; checked against vaultOwner at start.";
        };

        cliStateDir = lib.mkOption {
          type = lib.types.str;
          default = cliState;
          readOnly = true;
          description = "CLI daemon state: local PouchDB database and its settings.";
        };

        cliServiceName = lib.mkOption {
          type = lib.types.str;
          default = cliService;
          readOnly = true;
          description = "systemd service (without suffix) that runs the CLI daemon.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.opencloud.enable;
            message = "my.obsidianLivesync stores its data on the OpenCloud T7 and requires my.opencloud.enable.";
          }
          {
            assertion = config.virtualisation.docker.enable;
            message = "my.obsidianLivesync runs the LiveSync CLI with Docker; import self.nixosModules.docker.";
          }
        ];

        sops.secrets = {
          COUCHDB_ADMIN_PASSWORD = {
            sopsFile = secretsFile;
            mode = "0400";
            restartUnits = [ "couchdb-livesync-provision.service" ];
          };
          COUCHDB_AUTH_SECRET = {
            sopsFile = secretsFile;
            mode = "0400";
          };
          LIVESYNC_COUCHDB_PASSWORD = {
            sopsFile = secretsFile;
            mode = "0400";
            restartUnits = [
              "couchdb-livesync-provision.service"
              "${cliService}.service"
            ];
          };
          LIVESYNC_E2EE_PASSPHRASE = {
            sopsFile = secretsFile;
            mode = "0400";
            restartUnits = [ "${cliService}.service" ];
          };
        };

        # Read after the module-generated configuration, so the admin entries
        # and cookie secret never enter the Nix store. CouchDB hashes the
        # passwords into the writable local.ini, which is recreated at each start.
        #
        # The LiveSync account is a server admin because the plug-in's
        # "Overwrite server data" (and the CLI's rebuild) deletes and recreates
        # the database, which CouchDB reserves for server admins. The separate
        # maintenance admin is only used on HP by the provisioning service.
        sops.templates."couchdb-secrets.ini" = {
          owner = couchCfg.user;
          group = couchCfg.group;
          mode = "0400";
          restartUnits = [ "couchdb.service" ];
          content = ''
            [admins]
            ${adminUser} = ${config.sops.placeholder.COUCHDB_ADMIN_PASSWORD}
            ${cfg.couchUser} = ${config.sops.placeholder.LIVESYNC_COUCHDB_PASSWORD}

            [chttpd_auth]
            secret = ${config.sops.placeholder.COUCHDB_AUTH_SECRET}
          '';
        };

        # /srv/opencloud is root:opencloud 0710; membership grants traversal
        # to CouchDB's own subtree only.
        users.users.couchdb.extraGroups = [ "opencloud" ];

        systemd.tmpfiles.settings."10-obsidian-livesync" = {
          "${cfg.storageRoot}".d = {
            mode = "0710";
            user = "root";
            group = couchCfg.group;
          };
          "${cliState}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${cliState}/data".d = {
            mode = "0700";
            user = toString cfg.vaultUid;
            group = toString cfg.vaultGid;
          };
          "${cfg.vaultPath}".d = {
            mode = "0750";
            user = cfg.vaultOwner;
            group = "users";
          };
        };

        services.couchdb = {
          enable = true;
          bindAddress = "127.0.0.1";
          inherit (cfg) port;
          databaseDir = "${cfg.storageRoot}/data";
          viewIndexDir = "${cfg.storageRoot}/data";
          # Runtime configuration changes are deliberately not persisted: the
          # writable file lives in the runtime directory and is empty at start.
          configFile = "/run/couchdb/local.ini";
          extraConfigFiles = [ config.sops.templates."couchdb-secrets.ini".path ];
          # Settings from the LiveSync provisioning tool
          # (utils/couchdb/provision.ts), expressed declaratively.
          extraConfig = {
            # One replica per database on this single node (the upstream
            # setup's enable_single_node does the same).
            cluster.n = 1;
            couchdb = {
              single_node = true;
              max_document_size = 50000000;
              # Stable identity across restarts (otherwise persisted to local.ini).
              uuid = "c5755611203e6da7129d8018677308d5";
            };
            chttpd = {
              # Anonymous requests are refused except for the health endpoint.
              require_valid_user_except_for_up = true;
              max_http_request_size = 4294967296;
              enable_cors = true;
            };
            httpd = {
              "WWW-Authenticate" = ''Basic realm="couchdb"'';
              enable_cors = true;
            };
            cors = {
              credentials = true;
              origins = "app://obsidian.md,capacitor://localhost,http://localhost";
              headers = "accept, authorization, content-type, origin, referer, cf-access-client-id, cf-access-client-secret";
              methods = "GET, PUT, POST, HEAD, DELETE";
              max_age = 3600;
            };
          };
        };

        systemd.services.couchdb = {
          unitConfig = {
            RequiresMountsFor = "/srv/opencloud";
            ConditionPathIsMountPoint = "/srv/opencloud";
          };
          after = [ "srv-opencloud.mount" ];
          # The Erlang port mapper CouchDB spawns otherwise listens on all
          # interfaces; the node itself already uses loopback only.
          environment.ERL_EPMD_ADDRESS = "127.0.0.1";
          serviceConfig = {
            RuntimeDirectory = "couchdb";
            RuntimeDirectoryMode = "0700";
            Restart = "on-failure";
            RestartSec = 10;
            MemoryMax = "1G";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            # The tunnel and the host-network CLI container reach CouchDB on
            # loopback; nothing else may connect.
            IPAddressAllow = [ "localhost" ];
            IPAddressDeny = [ "any" ];
          };
        };

        systemd.services.couchdb-livesync-provision = {
          description = "Create the LiveSync CouchDB database, user, and permissions";
          # Also pulled in whenever CouchDB starts, e.g. after a backup stage.
          wantedBy = [
            "multi-user.target"
            "couchdb.service"
          ];
          requires = [ "couchdb.service" ];
          after = [ "couchdb.service" ];
          partOf = [ "couchdb.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = 10;
            ExecStart = "${provision}/bin/couchdb-livesync-provision";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };

        virtualisation.oci-containers = {
          backend = "docker";
          containers.obsidian-livesync-cli = {
            image = cliImageRef;
            imageFile = cliImage;
            serviceName = cliService;
            cmd = [
              "--vault"
              "/vault"
              "daemon"
            ];
            extraOptions = cliRunOptions;
          };
        };

        systemd.services.${cliService} = {
          requires = [ "couchdb-livesync-provision.service" ];
          after = [ "couchdb-livesync-provision.service" ];
          unitConfig = {
            # Initialised once by obsidian-livesync-hp-init; until then the
            # daemon must not scan the Vault directory against an empty database.
            ConditionPathExists = cliMarker;
            RequiresMountsFor = cfg.vaultPath;
          };
          serviceConfig = {
            ExecStartPre = lib.mkAfter [ "${cliSettingsApply}/bin/obsidian-livesync-cli-settings" ];
            MemoryMax = "1G";
          };
        };

        environment.systemPackages = [ cliInit ];

        my.opencloudTunnel.extraIngress.${cfg.host}.service = origin;
      };
    };
}
