# Noctalia desktop shell.
#
# v4 is the stable Quickshell implementation and retains the existing JSON
# exports. v5 is the in-development Rust/Lua implementation and uses TOML.
# Select one implementation per host with my.noctalia.version.

# export config after it has been set in GUI:
# V4 run: noctalia-shell ipc call state all | jq .settings > modules/features/desktop/noctalia/$(hostname).json
# V5 run: noctalia config export \ > modules/features/desktop/noctalia/v5/$(hostname).toml && noctalia config validate \ modules/features/desktop/noctalia/v5/$(hostname).toml

{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.noctalia =
    {
      config,
      lib,
      ...
    }:
    {
      options.my.noctalia.version = lib.mkOption {
        type = lib.types.enum [
          "v4"
          "v5"
        ];
        default = "v4";
        description = "Noctalia implementation to enable";
      };

      config = {
        nix.settings = {
          extra-substituters = [ "https://noctalia.cachix.org" ];
          extra-trusted-public-keys = [
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          ];
        };

        # Both shells use these services for their network, Bluetooth, battery,
        # and power-profile controls. tuned and power-profiles-daemon must not
        # run together, so laptops already using tuned keep it.
        networking.networkmanager.enable = lib.mkDefault true;
        hardware.bluetooth.enable = lib.mkDefault true;
        services.upower.enable = lib.mkDefault true;
        services.power-profiles-daemon.enable = lib.mkDefault (!config.services.tuned.enable);

        home-manager.sharedModules = [
          (
            if config.my.noctalia.version == "v5" then
              self.homeModules.noctalia-v5
            else
              self.homeModules.noctalia-v4
          )
        ];
      };
    };

  flake.homeModules.noctalia-v4 =
    { lib, osConfig, ... }:
    let
      hostname = osConfig.networking.hostName;
      settingsFile = ./. + "/${hostname}.json";
    in
    {
      imports = [ inputs.noctalia-v4.homeModules.default ];

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

  flake.homeModules.noctalia-v5 =
    { osConfig, ... }:
    let
      hostname = osConfig.networking.hostName;
      settingsFile = ./v5 + "/${hostname}.toml";
    in
    {
      imports = [ inputs.noctalia-v5.homeModules.default ];

      programs.noctalia = {
        enable = true;
        systemd.enable = true;
        settings = settingsFile;
      };
    };
}
