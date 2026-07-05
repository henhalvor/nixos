# Syncthing — declarative multi-device file synchronization
{ ... }:
{
  flake.nixosModules.syncthing =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.my.syncthing;
      homeDir = config.users.users.${cfg.user}.home;

      devices = {
        workstation.id = "VDQBMZD-3LCRWHG-7IZ7HLT-G3JQU25-SDUKIWP-BG4RMSA-VBZ6FNC-XPR5PQG";
        yoga-pro-7.id = "T2SDKBB-6W6PC6S-2MOF26Y-ISGI7GM-NV3G7U3-XQKVF7N-WD76D4R-IEIURQQ";
        android-phone.id = "GCRWWEH-SVM56QX-Z6BIO6J-LBVY2Z5-2KETSSL-ULFPLSQ-J25KU6W-GJIQTAO";
        android-tablet.id = "OMVTIWA-LM256KO-JDZPTK3-BTALD4W-LG6JTND-7VZQO7X-3KU5HEQ-LP6ELQX";
        hp-server.id = "32LVQHB-KVKBTRF-ZLOZATD-NAHXNFI-3SINNKH-DR4LGOB-HTGYK3O-UA3VPAZ";
      };

      folderTopology = {
        documents = {
          path = "Documents";
          participants = [
            "workstation"
            "yoga-pro-7"
          ];
          ignorePerms = false;
        };
        downloads = {
          path = "Downloads";
          participants = [
            "workstation"
            "android-phone"
          ];
          ignorePerms = true;
        };
        pictures = {
          path = "Pictures";
          participants = [
            "workstation"
            "yoga-pro-7"
          ];
          ignorePerms = false;
          ignorePatterns = [
            "/Camera"
            "/Screenshots"
          ];
        };
        music = {
          path = "Music";
          participants = [
            "workstation"
            "yoga-pro-7"
          ];
          ignorePerms = false;
        };
        camera = {
          path = "Pictures/Camera";
          participants = [
            "workstation"
            "yoga-pro-7"
            "android-phone"
          ];
          ignorePerms = true;
        };
        vault = {
          path = "Vault";
          participants = [
            "workstation"
            "yoga-pro-7"
            "android-phone"
            "android-tablet"
            "hp-server"
          ];
          ignorePerms = true;
        };
        screenshots = {
          path = "Pictures/Screenshots";
          participants = [
            "workstation"
            "yoga-pro-7"
            "android-phone"
          ];
          ignorePerms = true;
        };
        shared = {
          path = "Shared";
          participants = [
            "workstation"
            "yoga-pro-7"
            "android-phone"
            "android-tablet"
          ];
          ignorePerms = true;
        };
      };

      localFolders = lib.filterAttrs (
        _: folder: lib.elem cfg.deviceName folder.participants
      ) folderTopology;

      peerNames = lib.unique (
        lib.concatMap (folder: lib.filter (device: device != cfg.deviceName) folder.participants) (
          lib.attrValues localFolders
        )
      );

      folderSettings = lib.mapAttrs (
        name: folder:
        {
          id = name;
          label = name;
          path = "${homeDir}/${folder.path}";
          devices = lib.filter (device: device != cfg.deviceName) folder.participants;
          inherit (folder) ignorePerms;
        }
        // lib.optionalAttrs (folder ? ignorePatterns) {
          inherit (folder) ignorePatterns;
        }
      ) localFolders;

      folderPaths = map (folder: "${homeDir}/${folder.path}") (lib.attrValues localFolders);
      identityConfigured = cfg.identitySopsFile != null;
    in
    {
      options.my.syncthing = {
        user = lib.mkOption {
          type = lib.types.str;
          description = "User that owns the synchronized folders and runs Syncthing.";
        };

        deviceName = lib.mkOption {
          type = lib.types.enum (lib.attrNames devices);
          description = "Name of this host in the declarative Syncthing topology.";
        };

        identitySopsFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Host-specific SOPS file containing the existing Syncthing certificate and key.";
        };
      };

      config = {
        sops.secrets = lib.mkIf identityConfigured {
          syncthing-cert = {
            sopsFile = cfg.identitySopsFile;
            key = "cert";
            path = "/run/secrets/syncthing/cert.pem";
            owner = cfg.user;
            mode = "0400";
          };
          syncthing-key = {
            sopsFile = cfg.identitySopsFile;
            key = "key";
            path = "/run/secrets/syncthing/key.pem";
            owner = cfg.user;
            mode = "0400";
          };
        };

        systemd.services.syncthing-directories = {
          description = "Create local Syncthing directories";
          before = [ "syncthing.service" ];
          requiredBy = [ "syncthing.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            ExecStart = pkgs.writeShellScript "create-syncthing-dirs" (
              lib.concatMapStringsSep "\n" (path: "mkdir -p ${lib.escapeShellArg path}") folderPaths
            );
          };
        };

        services.syncthing = {
          enable = true;
          user = cfg.user;
          dataDir = "${homeDir}/.syncthing";
          configDir = "${homeDir}/.config/syncthing";
          guiAddress = "127.0.0.1:8384";
          openDefaultPorts = true;
          overrideDevices = true;
          overrideFolders = true;

          settings = {
            devices = lib.getAttrs peerNames devices;
            folders = folderSettings;
            options = {
              # maxSendKbps = 600;
              # maxRecvKbps = 600;
              limitBandwidthInLan = false;
              urAccepted = -1;
            };
          };
        }
        // lib.optionalAttrs identityConfigured {
          cert = config.sops.secrets.syncthing-cert.path;
          key = config.sops.secrets.syncthing-key.path;
        };
      };
    };
}
