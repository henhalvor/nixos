{...}: {
  flake.nixosModules.opencloudTunnel = {
    config,
    lib,
    ...
  }: let
    cfg = config.my.opencloudTunnel;
    cloudCfg = config.my.opencloud;
  in {
    options.my.opencloudTunnel = {
      tunnelId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "00000000-0000-0000-0000-000000000000";
        description = "Locally managed Cloudflare Tunnel UUID for OpenCloud and Keycloak.";
      };
    };

    config = lib.mkIf cloudCfg.enable {
      assertions = [{
        assertion = cfg.tunnelId != null;
        message = "my.opencloudTunnel.tunnelId must be set before enabling OpenCloud.";
      }];

      sops.secrets.CLOUDFLARED_TUNNEL_CREDENTIALS = {
        sopsFile = ../../../secrets/opencloud.yaml;
        owner = "root";
        group = "root";
        mode = "0400";
      };

      services.cloudflared = {
        enable = true;
        tunnels.${cfg.tunnelId} = {
          credentialsFile = config.sops.secrets.CLOUDFLARED_TUNNEL_CREDENTIALS.path;
          ingress = {
            "${cloudCfg.cloudHost}" = {
              service = "http://127.0.0.1:9200";
              originRequest.httpHostHeader = cloudCfg.cloudHost;
            };
            "${cloudCfg.authHost}" = {
              service = "http://127.0.0.1:8080";
              originRequest.httpHostHeader = cloudCfg.authHost;
            };
          };
          default = "http_status:404";
        };
      };
    };
  };
}
