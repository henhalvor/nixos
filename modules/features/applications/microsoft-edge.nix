# Microsoft Edge — browser with Wayland wrapper
# Source: home/modules/applications/microsoft-edge.nix
# Template B2: HM-only (uses pkgs-unstable for latest Edge)
# Note: Original used pkgs24-11; now uses pkgs directly (Edge is in stable nixpkgs)
{ self, ... }: {
  flake.nixosModules.microsoftEdge = { ... }: {
    home-manager.sharedModules = [ self.homeModules.microsoftEdge ];
  };

  flake.homeModules.microsoftEdge = { pkgs, ... }: let
    edge-wayland = pkgs.writeShellScriptBin "microsoft-edge-wayland" ''
      exec ${pkgs.microsoft-edge}/bin/microsoft-edge \
        --ozone-platform=wayland \
        --ozone-platform-hint=auto \
        --force-dark-mode \
        "$@"
    '';
  in {
    home.packages = [ pkgs.microsoft-edge edge-wayland ];

    xdg.desktopEntries.microsoft-edge-wayland = {
      name = "Edge (Wayland)";
      genericName = "Web Browser";
      exec = "microsoft-edge-wayland %U";
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "text/html"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      icon = "microsoft-edge";
    };

    xdg.desktopEntries.microsoft-edge = {
      name = "Microsoft Edge";
      exec = "microsoft-edge %U";
      noDisplay = true;
    };
  };
}
