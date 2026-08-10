# CalDAV/CardDAV storage behind OpenCloud's authenticated reverse proxy.
{ ... }:
{
  flake.nixosModules.opencloudRadicale =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.my.opencloud.radicale;
    in
    {
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.my.opencloud.enable;
            message = "my.opencloud.radicale requires my.opencloud.enable.";
          }
        ];

        # /srv/opencloud is root:opencloud 0710. Membership grants Radicale
        # traversal to its own private subtree without access to OpenCloud's
        # state directory.
        users.users.radicale.extraGroups = [ "opencloud" ];

        systemd.tmpfiles.settings."10-opencloud-radicale" = {
          "${cfg.storageRoot}".d = {
            mode = "0710";
            user = "root";
            group = "radicale";
          };
          "${cfg.storageRoot}/collections".d = {
            mode = "0700";
            user = "radicale";
            group = "radicale";
          };
          # Also repairs a lock file left with incorrect ownership by an
          # interrupted or older root-run maintenance command.
          "${cfg.storageRoot}/collections/.Radicale.lock".f = {
            mode = "0600";
            user = "radicale";
            group = "radicale";
          };
        };

        services.radicale = {
          enable = true;
          settings = {
            server = {
              hosts = [ "127.0.0.1:${toString cfg.port}" ];
              ssl = false;
            };
            auth = {
              # OpenCloud is the only caller and supplies the authenticated
              # account in X-Remote-User. Never expose this listener.
              type = "http_x_remote_user";
            };
            rights = {
              type = "owner_only";
            };
            storage = {
              type = "multifilesystem";
              filesystem_folder = "${cfg.storageRoot}/collections";
              folder_umask = "0077";
              predefined_collections = builtins.toJSON {
                def-addressbook = {
                  "D:displayname" = "Personal Address Book";
                  tag = "VADDRESSBOOK";
                };
                def-calendar = {
                  "C:supported-calendar-component-set" = "VEVENT,VJOURNAL,VTODO";
                  "D:displayname" = "Personal Calendar";
                  tag = "VCALENDAR";
                };
              };
            };
            web = {
              type = "none";
            };
            logging = {
              level = "info";
              mask_passwords = true;
              bad_put_request_content = false;
              request_header_on_debug = false;
              request_content_on_debug = false;
              response_content_on_debug = false;
            };
          };
        };

        systemd.services.radicale = {
          unitConfig = {
            RequiresMountsFor = "/srv/opencloud";
            ConditionPathIsMountPoint = "/srv/opencloud";
          };
          after = [ "srv-opencloud.mount" ];
          serviceConfig = {
            IPAddressAllow = [ "localhost" ];
            IPAddressDeny = [ "any" ];
          };
        };
      };
    };
}
