{...}: {
  flake.nixosModules.opencloudTunnel = {
    config,
    lib,
    ...
  }: let
    cfg = config.my.opencloudTunnel;
    cloudCfg = config.my.opencloud;
    opencloudIngress = lib.optionalAttrs cloudCfg.enable {
      "${cloudCfg.cloudHost}" = {
        service = "http://127.0.0.1:9200";
        originRequest.httpHostHeader = cloudCfg.cloudHost;
      };
      "${cloudCfg.authHost}" = {
        service = "http://127.0.0.1:8080";
        originRequest.httpHostHeader = cloudCfg.authHost;
      };
    };
    extraIngress = lib.mapAttrs (_: route:
      {inherit (route) service;}
      // lib.optionalAttrs (route.httpHostHeader != null) {
        originRequest.httpHostHeader = route.httpHostHeader;
      }) cfg.extraIngress;
    ingress = opencloudIngress // extraIngress;
  in {
    options.my.opencloudTunnel = {
      tunnelId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "00000000-0000-0000-0000-000000000000";
        description = "Locally managed Cloudflare Tunnel UUID. The identifier is public; its credential remains secret.";
      };
      extraIngress = lib.mkOption {
        default = {};
        description = "Additional explicit public hostnames routed through the existing outbound-only tunnel.";
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            service = lib.mkOption {
              type = lib.types.str;
              example = "http://127.0.0.1:3000";
              description = "Loopback origin served for this hostname.";
            };
            httpHostHeader = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional Host header sent to the local origin.";
            };
          };
        });
      };
    };

    config = lib.mkIf (ingress != {}) {
      assertions = [
        {
          assertion = cfg.tunnelId != null;
          message = "my.opencloudTunnel.tunnelId must be set before publishing tunnel ingress.";
        }
        {
          assertion = lib.all (route: lib.hasPrefix "http://127.0.0.1:" route.service) (lib.attrValues cfg.extraIngress);
          message = "my.opencloudTunnel.extraIngress origins must use an explicit http://127.0.0.1:<port> loopback URL.";
        }
      ];

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
          inherit ingress;
          default = "http_status:404";
        };
      };
    };
  };
}
