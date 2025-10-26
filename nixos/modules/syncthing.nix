{ config, pkgs, lib, userSettings, ... }:

{
  services.syncthing = {
    enable = true;
    user = userSettings.username;
    dataDir = "${userSettings.homeDirectory}/.syncthing";
    configDir = "${userSettings.homeDirectory}/.config/syncthing";
    openDefaultPorts = true;

    settings = {
      devices = {
        "workstation" = { id = "VDQBMZD-3LCRWHG-7IZ7HLT-G3JQU25-SDUKIWP-BG4RMSA-VBZ6FNC-XPR5PQG"; };
        "yoga-pro-7" = { id = "T2SDKBB-6W6PC6S-2MOF26Y-ISGI7GM-NV3G7U3-XQKVF7N-WD76D4R-IEIURQQ"; };
      };

      folders = {
        # Code projects - sync .git/ for seamless workflow
        "code" = {
          path = "${userSettings.homeDirectory}/code";
          devices = [ "workstation" "yoga-pro-7" ];
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
          devices = [ "workstation" "yoga-pro-7" ];
          ignorePerms = false;
        };

        # Downloads - safe to merge
        "downloads" = {
          path = "${userSettings.homeDirectory}/Downloads";
          devices = [ "workstation" "yoga-pro-7" ];
          ignorePerms = false;
        };

        # Pictures - safe to merge
        "pictures" = {
          path = "${userSettings.homeDirectory}/Pictures";
          devices = [ "workstation" "yoga-pro-7" ];
          ignorePerms = false;
        };

        # Music - safe to merge
        "music" = {
          path = "${userSettings.homeDirectory}/Music";
          devices = [ "workstation" "yoga-pro-7" ];
          ignorePerms = false;
        };
      };
    };
  };

  # Allow web UI access from network
  networking.firewall.allowedTCPPorts = [ 8384 ];
}
