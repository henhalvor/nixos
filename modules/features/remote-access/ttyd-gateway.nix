{...}: {
  flake.nixosModules.ttydWebTerminalGateway = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.ttydWebTerminalGateway;
    targetType = lib.types.submodule ({name, ...}: {
      options = {
        displayName = lib.mkOption {
          type = lib.types.nonEmptyStr;
          default = name;
        };
        path = lib.mkOption {
          type = lib.types.strMatching "^/[a-z0-9-]+/$";
        };
        upstream = lib.mkOption {
          type = lib.types.strMatching "^http://((127\\.0\\.0\\.1|100\\.[0-9]+\\.[0-9]+\\.[0-9]+):[0-9]+|unix:/run/ttyd-web-terminal/ttyd\\.sock:)$";
          description = "Fixed loopback or Tailscale ttyd origin.";
        };
      };
    });
    selector = pkgs.writeTextDir "index.html" ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1">
          <title>Remote terminals</title>
          <style>
            :root { color-scheme: dark; font-family: ui-monospace, monospace; }
            body { max-width: 46rem; margin: 10vh auto; padding: 2rem; background: #101418; color: #e7edf3; }
            h1 { font-size: 1.5rem; } ul { padding: 0; list-style: none; }
            a { display: block; margin: 1rem 0; padding: 1rem; color: #9bdcff; border: 1px solid #334455; border-radius: .4rem; text-decoration: none; }
            a:hover, a:focus { background: #18222b; border-color: #9bdcff; }
          </style>
        </head>
        <body>
          <h1>Choose a terminal</h1>
          <p>Each target is a separate host-local session.</p>
          <ul>
            ${lib.concatMapStrings (target: ''<li><a href="${target.path}">${lib.escapeXML target.displayName}</a></li>'') (lib.attrValues cfg.targets)}
          </ul>
          <p><a href="/oauth2/sign_out">Sign out</a></p>
        </body>
      </html>
    '';
    targetLocations = lib.listToAttrs (lib.mapAttrsToList (_: target:
      lib.nameValuePair target.path {
        proxyPass = target.upstream;
        proxyWebsockets = true;
        extraConfig = ''
          # ttyd's same-origin WebSocket check compares Origin with Host. Keep
          # the browser's authenticated public host across the Unix socket.
          proxy_set_header Host ${cfg.publicHost};
          proxy_set_header Authorization "";
          proxy_set_header X-Forwarded-Access-Token "";
          proxy_set_header X-Forwarded-Email "";
          # oauth2-proxy documents that X-Forwarded-User can be empty for
          # some OIDC sessions. A verified email is mandatory in this flow,
          # so use it only as ttyd's non-empty authenticated marker.
          proxy_set_header X-TTYD-User $http_x_forwarded_email;
          proxy_read_timeout 86400s;
          proxy_send_timeout 86400s;
        '';
      })
    cfg.targets);
  in {
    options.my.ttydWebTerminalGateway = {
      enable = lib.mkEnableOption "the Keycloak-authenticated ttyd gateway";
      publicHost = lib.mkOption {type = lib.types.nonEmptyStr;};
      authHost = lib.mkOption {type = lib.types.nonEmptyStr;};
      secretFile = lib.mkOption {type = lib.types.path;};
      oauthPort = lib.mkOption {
        type = lib.types.port;
        default = 4180;
      };
      gatewayPort = lib.mkOption {
        type = lib.types.port;
        default = 4181;
      };
      targets = lib.mkOption {
        type = lib.types.attrsOf targetType;
        default = {};
      };
    };

    config = lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.targets != {};
          message = "The ttyd gateway requires at least one fixed target.";
        }
        {
          assertion = cfg.oauthPort != cfg.gatewayPort;
          message = "OAuth and gateway ports must differ.";
        }
        {
          assertion = config.services.keycloak.enable;
          message = "The ttyd gateway requires the local Keycloak service.";
        }
        {
          assertion = lib.length (lib.unique (map (target: target.path) (lib.attrValues cfg.targets))) == lib.length (lib.attrValues cfg.targets);
          message = "Every ttyd target must have a unique path.";
        }
      ];

      sops.secrets.TTYD_OIDC_CLIENT_SECRET = {
        sopsFile = cfg.secretFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      sops.secrets.TTYD_OAUTH_COOKIE_SECRET = {
        sopsFile = cfg.secretFile;
        owner = "root";
        group = "root";
        mode = "0400";
      };
      sops.templates."ttyd-oauth2-proxy-env" = {
        owner = "root";
        group = "oauth2-proxy";
        mode = "0440";
        content = ''
          OAUTH2_PROXY_CLIENT_SECRET=${config.sops.placeholder.TTYD_OIDC_CLIENT_SECRET}
          OAUTH2_PROXY_COOKIE_SECRET=${config.sops.placeholder.TTYD_OAUTH_COOKIE_SECRET}
        '';
      };

      services.oauth2-proxy = {
        enable = true;
        provider = "keycloak-oidc";
        clientID = "ttyd";
        oidcIssuerUrl = "https://${cfg.authHost}/realms/terminal";
        redirectURL = "https://${cfg.publicHost}/oauth2/callback";
        httpAddress = "http://127.0.0.1:${toString cfg.oauthPort}";
        upstream = ["http://127.0.0.1:${toString cfg.gatewayPort}/"];
        scope = "openid profile email";
        email.domains = ["*"];
        passAccessToken = false;
        passBasicAuth = false;
        passHostHeader = true;
        reverseProxy = true;
        requestLogging = false;
        cookie = {
          domain = null;
          expire = "8h";
          refresh = "15m";
          httpOnly = true;
          secure = true;
          name = "__Host-ttyd_session";
        };
        keyFile = config.sops.templates."ttyd-oauth2-proxy-env".path;
        extraConfig = {
          allowed-role = "ttyd-user";
          code-challenge-method = "S256";
          cookie-samesite = "lax";
          cookie-path = "/";
          pass-authorization-header = false;
          pass-user-headers = true;
          proxy-websockets = true;
          silence-ping-logging = true;
          skip-auth-strip-headers = true;
          skip-provider-button = true;
          whitelist-domain = cfg.publicHost;
        };
      };

      services.nginx = {
        enable = true;
        virtualHosts."ttyd-web-terminal-gateway" = {
          listen = [
            {
              addr = "127.0.0.1";
              port = cfg.gatewayPort;
            }
          ];
          locations =
            targetLocations
            // {
            "= /" = {
              root = selector;
              tryFiles = "/index.html =404";
            };
              "/" = {return = "404";};
            };
        };
      };

      systemd.services.oauth2-proxy = {
        after = ["nginx.service" "keycloak.service"];
        wants = ["nginx.service" "keycloak.service"];
        serviceConfig = {
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          CapabilityBoundingSet = "";
          RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
        };
      };
    };
  };
}
