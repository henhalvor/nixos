# Syncthing — file synchronization
# Source: nixos/modules/syncthing.nix
# Defines options.my.syncthing.user so the host/user module specifies the user.
{...}: {
  flake.nixosModules.syncthing = {
    config,
    pkgs,
    lib,
    ...
  }: let
    cfg = config.my.syncthing;
    homeDir = config.users.users.${cfg.user}.home;
  in {
    options.my.syncthing = {
      user = lib.mkOption {
        type = lib.types.str;
        description = "Username for Syncthing service";
      };
    };

    config = {
      # Auto-create sync folders before Syncthing starts
      systemd.services.syncthing-directories = {
        description = "Create Syncthing directories";
        before = ["syncthing.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          User = cfg.user;
          ExecStart = pkgs.writeShellScript "create-syncthing-dirs" ''
            mkdir -p \
              "${homeDir}/Pictures/Camera" \
              "${homeDir}/Pictures/Screenshots" \
              "${homeDir}/Shared" \
              "${homeDir}/Vault"
          '';
        };
      };

      services.syncthing = {
        enable = true;
        user = cfg.user;
        dataDir = "${homeDir}/.syncthing";
        configDir = "${homeDir}/.config/syncthing";
        openDefaultPorts = true;

        settings = {
          devices = {
            "workstation" = {id = "VDQBMZD-3LCRWHG-7IZ7HLT-G3JQU25-SDUKIWP-BG4RMSA-VBZ6FNC-XPR5PQG";};
            "yoga-pro-7" = {id = "T2SDKBB-6W6PC6S-2MOF26Y-ISGI7GM-NV3G7U3-XQKVF7N-WD76D4R-IEIURQQ";};
            "android-phone" = {id = "GCRWWEH-SVM56QX-Z6BIO6J-LBVY2Z5-2KETSSL-ULFPLSQ-J25KU6W-GJIQTAO";};
            "android-tablet" = {id = "OMVTIWA-LM256KO-JDZPTK3-BTALD4W-LG6JTND-7VZQO7X-3KU5HEQ-LP6ELQX";};
            "hp-server" = {id = "32LVQHB-KVKBTRF-ZLOZATD-NAHXNFI-3SINNKH-DR4LGOB-HTGYK3O-UA3VPAZ";};
          };

          folders = {
            "code" = {
              path = "${homeDir}/code";
              devices = ["workstation" "yoga-pro-7" "hp-server"];
              ignorePerms = false;
            };
            "documents" = {
              path = "${homeDir}/Documents";
              devices = ["workstation" "yoga-pro-7"];
              ignorePerms = false;
            };
            "downloads" = {
              path = "${homeDir}/Downloads";
              devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
              ignorePerms = true;
            };
            "pictures" = {
              path = "${homeDir}/Pictures";
              devices = ["workstation" "yoga-pro-7"];
              ignorePerms = false;
            };
            "music" = {
              path = "${homeDir}/Music";
              devices = ["workstation" "yoga-pro-7"];
              ignorePerms = false;
            };
            "camera" = {
              path = "${homeDir}/Pictures/Camera";
              devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
              ignorePerms = true;
            };
            "vault" = {
              path = "${homeDir}/Vault";
              devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet" "hp-server"];
              ignorePerms = true;
            };
            "screenshots" = {
              path = "${homeDir}/Pictures/Screenshots";
              devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
              ignorePerms = true;
            };
            "shared" = {
              path = "${homeDir}/Shared";
              devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
              ignorePerms = true;
            };
          };
        };
      };

      networking.firewall.allowedTCPPorts = [8384];
    };
  };
}
