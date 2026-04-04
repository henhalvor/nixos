# Vivaldi — browser with custom left-tabs CSS
# Source: home/modules/applications/vivaldi.nix
# Template B2: HM-only
{self, ...}: {
  flake.nixosModules.vivaldi = {...}: {
    home-manager.sharedModules = [self.homeModules.vivaldi];
  };

  flake.homeModules.vivaldi = {pkgs, ...}: {
    home.packages = with pkgs; [vivaldi];

    # xdg.mimeApps = {
    #   enable = true;
    #   defaultApplications = {
    #     "text/html" = [ "vivaldi-stable.desktop" ];
    #     "x-scheme-handler/http" = [ "vivaldi-stable.desktop" ];
    #     "x-scheme-handler/https" = [ "vivaldi-stable.desktop" ];
    #     "x-scheme-handler/chrome" = [ "vivaldi-stable.desktop" ];
    #     "application/x-extension-htm" = [ "vivaldi-stable.desktop" ];
    #     "application/x-extension-html" = [ "vivaldi-stable.desktop" ];
    #     "application/x-extension-shtml" = [ "vivaldi-stable.desktop" ];
    #     "application/xhtml+xml" = [ "vivaldi-stable.desktop" ];
    #     "application/x-extension-xhtml" = [ "vivaldi-stable.desktop" ];
    #     "application/x-extension-xht" = [ "vivaldi-stable.desktop" ];
    #   };
    # };

    # Expanding left-tabs CSS
    home.file.".config/vivaldi/custom.css".text = ''
      /* Expanding Left Tabs */
      #tabs-tabbar-container.left {
          transition: all 100ms ease !important;
          width: 30px;
      }
      #tabs-tabbar-container.left:hover {
          width: 250px !important;
      }
      .tabbar-wrapper {
          position: absolute !important;
          z-index: 200 !important;
          height: 100% !important;
          transition: all 100ms ease !important;
          width: 30px;
      }
      .tabbar-wrapper:hover {
          width: 250px !important;
      }
      #webview-container {
          margin-left: 30px;
      }
      @media all and (display-mode: fullscreen) {
          #webview-container {
              margin-left: 0 !important;
          }
      }
      #webview-container ~ .StatusInfo {
          left: 36px !important;
      }
      .newtab {
          opacity: 0;
      }
      #tabs-tabbar-container.left:hover .newtab {
          opacity: 1 !important;
          transition: opacity 200ms ease 250ms;
      }
    '';
  };
}
