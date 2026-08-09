# OpenCloud on the dedicated HP data filesystem.  This module deliberately
# remains disabled until the provider-side hostname, tunnel, and SOPS profile
# have been provisioned; see docs/runbooks/phase-5-deployment.md.
{...}: {
  flake.nixosModules.opencloud = {
    config,
    lib,
    pkgs,
    pkgs-unstable,
    ...
  }: let
    cfg = config.my.opencloud;
  in {
    options.my.opencloud = {
      enable = lib.mkEnableOption "OpenCloud on HP's dedicated removable data filesystem";

      cloudHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "cloud.example.com";
        description = "Public OpenCloud hostname routed through Cloudflare Tunnel.";
      };

      authHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "auth.example.com";
        description = "Public Keycloak OIDC hostname routed through Cloudflare Tunnel.";
      };

      storageUuid = lib.mkOption {
        type = lib.types.str;
        default = "e4577487-f1c0-4aee-bea3-daac8df1633d";
        readOnly = true;
        description = "UUID of the verified Samsung T7 ext4 OpenCloud filesystem.";
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.cloudHost != null;
          message = "my.opencloud.cloudHost must be set before enabling OpenCloud.";
        }
        {
          assertion = cfg.authHost != null;
          message = "my.opencloud.authHost must be set before enabling OpenCloud.";
        }
      ];

      fileSystems."/srv/opencloud" = {
        device = "/dev/disk/by-uuid/${cfg.storageUuid}";
        fsType = "ext4";
        # This is a removable USB filesystem.  A missing disk must not block
        # boot, and ConditionPathIsMountPoint below prevents a root-fs fallback.
        options = [
          "nofail"
          "noatime"
          "x-systemd.device-timeout=10s"
          "x-systemd.mount-timeout=10s"
        ];
      };

      systemd.tmpfiles.settings."10-opencloud-backup" = {
        # The removable filesystem may retain ownership from formatting or a
        # previous mount.  OpenCloud needs traversal (but not directory
        # listing) to reach its private state directory.
        "/srv/opencloud".d = {
          mode = "0710";
          user = "root";
          group = "opencloud";
        };
        "/srv/opencloud/backup-staging".d = {
          mode = "0700";
          user = "root";
          group = "root";
        };
      };

      # The web client must be permitted to redirect to and query the external
      # Keycloak issuer. Without this, OpenCloud's default CSP allows only its
      # own origin and the browser remains on the login spinner.
      environment.etc."opencloud/csp.yaml".text = ''
        directives:
          child-src:
            - "'self'"
          connect-src:
            - "'self'"
            - "blob:"
            - "https://${cfg.authHost}/"
            - "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
            - "https://update.opencloud.eu/"
          default-src:
            - "'none'"
          font-src:
            - "'self'"
          frame-ancestors:
            - "'self'"
          frame-src:
            - "'self'"
            - "blob:"
            - "https://embed.diagrams.net/"
            - "https://${cfg.authHost}/"
          img-src:
            - "'self'"
            - "data:"
            - "blob:"
            - "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
          manifest-src:
            - "'self'"
          media-src:
            - "'self'"
          object-src:
            - "'self'"
            - "blob:"
          script-src:
            - "'self'"
            - "'unsafe-inline'"
            - "https://${cfg.authHost}/"
          style-src:
            - "'self'"
            - "'unsafe-inline'"
          worker-src:
            - "'self'"
            - "blob:"
      '';

      # Autoprovisioning uses a separate, loopback-only LDAP directory. The
      # bind password is shared only by OpenLDAP's root DN and the OpenCloud
      # service; neither is exposed through the public tunnel.
      sops.secrets.OPENLDAP_BIND_PASSWORD = {
        sopsFile = ../../../secrets/opencloud.yaml;
        owner = "openldap";
        group = "openldap";
        mode = "0400";
      };
      sops.templates."opencloud-env" = {
        owner = "opencloud";
        group = "opencloud";
        mode = "0400";
        content = ''
          OC_LDAP_BIND_PASSWORD=${config.sops.placeholder.OPENLDAP_BIND_PASSWORD}
        '';
      };

      services.openldap = {
        enable = true;
        # This is deliberately a loopback-only, unencrypted LDAP connection.
        # It is never exposed through Cloudflare, the LAN, or the firewall.
        urlList = [ "ldap://127.0.0.1:1389/" ];
        settings = {
          attrs.olcLogLevel = "stats";
          children = {
            "cn=schema".includes = [
              "${pkgs.openldap}/etc/schema/core.ldif"
              "${pkgs.openldap}/etc/schema/cosine.ldif"
              "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
              ./opencloud-ldap-schema.ldif
            ];
            "olcDatabase={-1}frontend".attrs = {
              objectClass = "olcDatabaseConfig";
              olcDatabase = "{-1}frontend";
              olcAccess = [ "{0}to * by dn.exact=uidNumber=0+gidNumber=0,cn=peercred,cn=external,cn=auth manage by * none" ];
            };
            "olcDatabase={0}config".attrs = {
              objectClass = "olcDatabaseConfig";
              olcDatabase = "{0}config";
              olcAccess = [ "{0}to * by * none break" ];
            };
            "olcDatabase={1}mdb".attrs = {
              objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];
              olcDatabase = "{1}mdb";
              olcDbDirectory = "/var/lib/openldap/opencloud";
              olcDbIndex = [
                "objectClass eq"
                "uid pres,eq,sub"
                "openCloudUUID eq"
              ];
              olcSuffix = "dc=opencloud,dc=eu";
              olcRootDN = "cn=admin,dc=opencloud,dc=eu";
              olcRootPW = { path = config.sops.secrets.OPENLDAP_BIND_PASSWORD.path; };
              olcAccess = [
                "{0}to attrs=userPassword by dn.exact=cn=admin,dc=opencloud,dc=eu manage by self write by anonymous auth by * none"
                "{1}to * by dn.exact=cn=admin,dc=opencloud,dc=eu manage by * none"
              ];
            };
          };
        };
      };

      # `declarativeContents` would erase dynamically provisioned users on
      # every restart. Seed only the directory structure on its first start.
      systemd.services.opencloud-ldap-init = {
        description = "Seed the OpenCloud autoprovisioning LDAP directory";
        requires = [ "openldap.service" ];
        after = [ "openldap.service" ];
        before = [ "opencloud.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.openldap ];
        script = ''
          set -euo pipefail
          if ! ldapsearch -x -LLL -H ldap://127.0.0.1:1389 \
            -D cn=admin,dc=opencloud,dc=eu \
            -y ${config.sops.secrets.OPENLDAP_BIND_PASSWORD.path} \
            -b dc=opencloud,dc=eu -s base >/dev/null 2>&1; then
            ldapadd -x -H ldap://127.0.0.1:1389 \
              -D cn=admin,dc=opencloud,dc=eu \
              -y ${config.sops.secrets.OPENLDAP_BIND_PASSWORD.path} \
              -f ${./opencloud-ldap-base.ldif}
          fi
        '';
      };

      services.opencloud = {
        enable = true;
        # All three assets must come from the same unstable OpenCloud family.
        package = pkgs-unstable.opencloud;
        webPackage = pkgs-unstable.opencloud.web;
        idpWebPackage = pkgs-unstable.opencloud.idp-web;
        stateDir = "/srv/opencloud/state";
        address = "127.0.0.1";
        port = 9200;
        url = "https://${cfg.cloudHost}";
        environment = {
          OC_INSECURE = "true";
          PROXY_TLS = "false";
          OC_OIDC_ISSUER = "https://${cfg.authHost}/realms/opencloud";
          # Autoprovisioning replaces both built-in identity components with
          # Keycloak and the managed local OpenLDAP directory above.
          OC_EXCLUDE_RUN_SERVICES = "idm,idp";
          PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD = "jwt";
          PROXY_OIDC_REWRITE_WELLKNOWN = "true";
          PROXY_CSP_CONFIG_FILE_LOCATION = "/etc/opencloud/csp.yaml";
          # Keycloak is the interactive identity source. Accounts are created
          # in OpenCloud's local IDM on their first successful Keycloak login;
          # Keycloak's immutable `sub` claim remains the account identifier if
          # the person later changes their login name.
          WEB_OPTION_ACCOUNT_EDIT_LINK_HREF = "https://${cfg.authHost}/realms/opencloud/account";
          PROXY_USER_OIDC_CLAIM = "sub";
          PROXY_USER_CS3_CLAIM = "username";
          PROXY_AUTOPROVISION_ACCOUNTS = "true";
          PROXY_AUTOPROVISION_CLAIM_USERNAME = "sub";
          OC_LDAP_URI = "ldap://127.0.0.1:1389";
          OC_LDAP_BIND_DN = "cn=admin,dc=opencloud,dc=eu";
          OC_LDAP_GROUP_BASE_DN = "ou=groups,dc=opencloud,dc=eu";
          OC_LDAP_USER_BASE_DN = "ou=users,dc=opencloud,dc=eu";
          OC_LDAP_USER_FILTER = "(objectclass=inetOrgPerson)";
          OC_LDAP_SERVER_WRITE_ENABLED = "true";
          OC_LDAP_USER_SCHEMA_ID = "openCloudUUID";
          OC_LDAP_GROUP_SCHEMA_ID = "openCloudUUID";
          OC_LDAP_DISABLE_USER_MECHANISM = "attribute";
          GRAPH_USERNAME_MATCH = "none";

          # The `roles` claim comes from the Keycloak realm-role mapper.
          # `opencloudAdmin`, `opencloudSpaceAdmin`, `opencloudUser`, and
          # `opencloudGuest` use OpenCloud's documented default role mapping.
          PROXY_ROLE_ASSIGNMENT_DRIVER = "oidc";
          PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM = "roles";
          GRAPH_ASSIGN_DEFAULT_USER_ROLE = "false";
          SETTINGS_SETUP_DEFAULT_ASSIGNMENTS = "false";
          # HP already uses OpenCloud's defaults 9119 (Hermes) and 9120
          # (nginx); Search also reserves 9220. These are private component
          # listeners only; keep the public proxy boundary on 127.0.0.1:9200.
          WEBDAV_DEBUG_ADDR = "127.0.0.1:9219";
          GRAPH_HTTP_ADDR = "127.0.0.1:19220";
        };
        environmentFile = config.sops.templates."opencloud-env".path;
      };

      systemd.services.opencloud = {
        unitConfig = {
          RequiresMountsFor = "/srv/opencloud";
          ConditionPathIsMountPoint = "/srv/opencloud";
        };
        requires = [ "opencloud-ldap-init.service" ];
        after = [ "opencloud-ldap-init.service" ];
      };
    };
  };
}
