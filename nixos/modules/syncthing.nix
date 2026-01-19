{
  config,
  pkgs,
  lib,
  userSettings,
  ...
}: {
  # Auto create folders if not exists
  systemd.services.syncthing-directories = {
    description = "Create Syncthing directories";
    before = ["syncthing.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      User = userSettings.username;
      ExecStart = pkgs.writeShellScript "create-syncthing-dirs" ''
        mkdir -p \
          "${userSettings.homeDirectory}/Pictures/Camera" \
          "${userSettings.homeDirectory}/Pictures/Screenshots" \
          "${userSettings.homeDirectory}/Shared"
      '';
    };
  };

  services.syncthing = {
    enable = true;
    user = userSettings.username;
    dataDir = "${userSettings.homeDirectory}/.syncthing";
    configDir = "${userSettings.homeDirectory}/.config/syncthing";
    openDefaultPorts = true;

    settings = {
      devices = {
        "workstation" = {id = "VDQBMZD-3LCRWHG-7IZ7HLT-G3JQU25-SDUKIWP-BG4RMSA-VBZ6FNC-XPR5PQG";};
        "yoga-pro-7" = {id = "T2SDKBB-6W6PC6S-2MOF26Y-ISGI7GM-NV3G7U3-XQKVF7N-WD76D4R-IEIURQQ";};
        "android-phone" = {id = "GCRWWEH-SVM56QX-Z6BIO6J-LBVY2Z5-2KETSSL-ULFPLSQ-J25KU6W-GJIQTAO";};
        "android-tablet" = {id = "OMVTIWA-LM256KO-JDZPTK3-BTALD4W-LG6JTND-7VZQO7X-3KU5HEQ-LP6ELQX";};
      };

      folders = {
        # Code projects - sync .git/ for seamless workflow
        "code" = {
          path = "${userSettings.homeDirectory}/code";
          devices = ["workstation" "yoga-pro-7"];
          ignorePerms = false;
        };

        # # Dotfiles - sync .git/ since workstation is source of truth
        # "dotfiles" = {
        #   path = "${userSettings.homeDirectory}/.dotfiles";
        #   devices = [ "workstation" "yoga-pro-7" ];
        #   ignorePerms = false;
        # };

        # Documents - safe to merge
        "documents" = {
          path = "${userSettings.homeDirectory}/Documents";
          devices = ["workstation" "yoga-pro-7"];
          ignorePerms = false;
        };

        # Downloads - sync between all devices
        "downloads" = {
          path = "${userSettings.homeDirectory}/Downloads";
          devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
          ignorePerms = true; # Needed for Android
        };

        # Pictures - safe to merge
        "pictures" = {
          path = "${userSettings.homeDirectory}/Pictures";
          devices = ["workstation" "yoga-pro-7"];
          ignorePerms = false;
        };

        # Music - safe to merge
        "music" = {
          path = "${userSettings.homeDirectory}/Music";
          devices = ["workstation" "yoga-pro-7"];
          ignorePerms = false;
        };

        # Camera folder - sync between all devices
        "camera" = {
          path = "${userSettings.homeDirectory}/Pictures/Camera";
          devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
          ignorePerms = true; # Needed for Android
        };

        # Screenshots folder - sync between all devices
        "screenshots" = {
          path = "${userSettings.homeDirectory}/Pictures/Screenshots";
          devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
          ignorePerms = true; # Needed for Android
        };

        # Shared folder - sync between all devices
        "shared" = {
          path = "${userSettings.homeDirectory}/Shared";
          devices = ["workstation" "yoga-pro-7" "android-phone" "android-tablet"];
          ignorePerms = true; # Needed for Android
        };
      };
    };
  };

  # Allow web UI access from network
  networking.firewall.allowedTCPPorts = [8384];
}
