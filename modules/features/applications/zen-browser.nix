# Zen Browser — privacy-focused browser (from flake input)
# Source: home/modules/applications/zen-browser.nix
# Template B2: HM-only (uses inputs.zen-browser)
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.zenBrowser = {...}: {
    home-manager.sharedModules = [self.homeModules.zenBrowser];
  };

  flake.homeModules.zenBrowser = {pkgs, ...}: {
    home.packages = [inputs.zen-browser.packages.${pkgs.system}.default];

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/chrome" = "zen-beta.desktop";
      "application/x-extension-htm" = "zen-beta.desktop";
      "application/x-extension-html" = "zen-beta.desktop";
      "application/x-extension-shtml" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "application/x-extension-xhtml" = "zen-beta.desktop";
      "application/x-extension-xht" = "zen-beta.desktop";
    };
  };
}
