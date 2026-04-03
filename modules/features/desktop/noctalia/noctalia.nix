# Noctalia — desktop shell (bar, notifications, launcher, logout)
# Source: home/modules/desktop/shells/noctalia/default.nix
# Template B2: HM-only, imports noctalia flake input
#
# Settings in noctalia/settings.json (co-located).
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

  flake.homeModules.noctalia = {lib, ...}: {
    imports = [inputs.noctalia.homeModules.default];

    programs.noctalia-shell = {
      enable = true;
      systemd.enable = true;
      settings = lib.mkDefault (builtins.fromJSON (builtins.readFile ./settings.json));
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
        };
      };

      pluginSettings = {
        kde-connect = {
        };
        # this may also be a string or a path to a JSON file.
      };
    };
  };
}
