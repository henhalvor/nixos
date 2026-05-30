# Noctalia — desktop shell (bar, notifications, launcher, logout)
# Source: home/modules/desktop/shells/noctalia/default.nix
# Template B2: HM-only, imports noctalia flake input
#
# Settings are host-exact JSON exports, co-located in this directory.
# Generate/update from the target host after configuring Noctalia manually:
#   noctalia-shell ipc call state all | jq .settings > modules/features/desktop/noctalia/$(hostname).json
# When noctalia manages bar/notifications/logout, those individual features
# should NOT be imported for the same host.
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.noctalia = {...}: {
    home-manager.sharedModules = [self.homeModules.noctalia];
  };

  flake.homeModules.noctalia = {lib, osConfig, ...}: let
    hostname = osConfig.networking.hostName;
    settingsFile = ./. + "/${hostname}.json";
  in {
    imports = [inputs.noctalia.homeModules.default];

    programs.noctalia-shell = {
      enable = true;
      systemd.enable = true;
      settings = lib.mkForce (builtins.fromJSON (builtins.readFile settingsFile));
      plugins = {
        sources = [
          {
            enabled = true;
            name = "Official Noctalia Plugins";
            url = "https://github.com/noctalia-dev/noctalia-plugins";
          }
        ];
        states = {
          kde-connect = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          tailscale = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          syncthing-status = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };

          keybind-cheatsheet = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          usb-drive-manager = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
      };

      pluginSettings = {
        kde-connect = {
        };
        tailscale = {
          compactMode = true;
        };
        syncthing-status = {
        };
        keybind-cheatsheet = {
        };
        usb-drive-manager = {
        };
        # Add other plugins here
        # this may also be a string or a path to a JSON file.
      };
    };
  };
}
