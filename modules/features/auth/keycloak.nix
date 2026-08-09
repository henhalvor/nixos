# Keycloak is the sole interactive identity provider for OpenCloud.  Realm,
# client, role-mapping, and MFA policy are provider data and are intentionally
# not guessed in Nix; the activation runbook creates and verifies them.
{...}: {
  flake.nixosModules.opencloudKeycloak = {
    config,
    lib,
    ...
  }: let
    cloudCfg = config.my.opencloud;
  in {
    config = lib.mkIf cloudCfg.enable {
      sops.secrets.KEYCLOAK_DB_PASSWORD = {
        sopsFile = ../../../secrets/opencloud.yaml;
        # The upstream Keycloak unit uses DynamicUser=yes.  Its service
        # manager reads this root-owned source and passes it as a systemd
        # credential, so there must not be a persistent `keycloak` owner here.
        owner = "root";
        group = "root";
        mode = "0400";
      };
      sops.secrets.KEYCLOAK_ADMIN_PASSWORD = {
        sopsFile = ../../../secrets/opencloud.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      sops.templates."keycloak-bootstrap-env" = {
        owner = "root";
        group = "root";
        mode = "0400";
        content = ''
          KC_BOOTSTRAP_ADMIN_USERNAME=admin
          KC_BOOTSTRAP_ADMIN_PASSWORD=${config.sops.placeholder.KEYCLOAK_ADMIN_PASSWORD}
        '';
      };

      services.keycloak = {
        enable = true;
        database = {
          type = "postgresql";
          createLocally = true;
          passwordFile = config.sops.secrets.KEYCLOAK_DB_PASSWORD.path;
        };
        settings = {
          http-enabled = true;
          http-host = "127.0.0.1";
          http-port = 8080;
          # Keycloak's option is the hostname, not a complete URL.
          hostname = cloudCfg.authHost;
          hostname-strict = true;
          hostname-backchannel-dynamic = false;
          proxy-headers = "xforwarded";
          proxy-trusted-addresses = "127.0.0.1/32,::1/128";
        };
      };

      # initialAdminPassword would embed the value in the Nix store.  The
      # module's generated service is extended with a root-only runtime file.
      systemd.services.keycloak.serviceConfig.EnvironmentFile =
        config.sops.templates."keycloak-bootstrap-env".path;
    };
  };
}
