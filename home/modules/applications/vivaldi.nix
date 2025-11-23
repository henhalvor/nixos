{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable Vivaldi and its features
  programs.vivaldi = {
    enable = true;
    package = pkgs.vivaldi; # You could also use vivaldi-ffmpeg-codecs for better media support

    # Command line arguments passed to Vivaldi on startup
    commandLineArgs = [
      "--force-dark-mode" # Enables dark mode regardless of system theme
      "--enable-features=UseOzonePlatform" # Better Wayland support
      "--ozone-platform=wayland" # Native Wayland support
      "--enable-features=VaapiVideoDecoder" # Hardware video acceleration
      "--disable-features=UseChromeOSDirectVideoDecoder" # Prevents conflicts with VAAPI
    ];

    # Install extensions. Find the extension ID in the Chrome Web Store URL:
    #   https://chrome.google.com/webstore/detail/<name>/<extension-id>
    extensions = [
      # Example: uBlock Origin (store id)
      {id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";}

      # # Example: an extension with a custom update XML
      # {
      #   id = "dcpihecpambacapedldabdbpakmachpb";
      #   updateUrl = "https://raw.githubusercontent.com/iamadamdev/bypass-paywalls-chrome/master/updates.xml";
      # }
      #
      # # Example: local CRX file (Linux only). crxPath must be an absolute path; version required
      # {
      #   id = "aaaaaaaaaabbbbbbbbbbcccccccccc";
      #   crxPath = /home/henhalvor/share/my-theme-or-extension.crx;
      #   version = "1.0";
      # }
    ];

    # Optional: dictionaries to install into Vivaldi's Dictionaries directory
    dictionaries = [
      pkgs.hunspellDictsChromium.en_US
    ];
  };

  # Additional packages that enhance Vivaldi's functionality
  home.packages = with pkgs; [
    vivaldi-ffmpeg-codecs # Additional codec support for better media playback
    # widevine-cdm # Required for streaming services like Netflix
  ];

  # Optional: Configure XDG MIME types to make Vivaldi the default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = ["vivaldi-stable.desktop"];
      "x-scheme-handler/http" = ["vivaldi-stable.desktop"];
      "x-scheme-handler/https" = ["vivaldi-stable.desktop"];
      "x-scheme-handler/chrome" = ["vivaldi-stable.desktop"];
      "application/x-extension-htm" = ["vivaldi-stable.desktop"];
      "application/x-extension-html" = ["vivaldi-stable.desktop"];
      "application/x-extension-shtml" = ["vivaldi-stable.desktop"];
      "application/xhtml+xml" = ["vivaldi-stable.desktop"];
      "application/x-extension-xhtml" = ["vivaldi-stable.desktop"];
      "application/x-extension-xht" = ["vivaldi-stable.desktop"];
    };
  };

  # Tabs
  home.file.".config/vivaldi/custom.css".text = ''

    /* Expanding Left Tabs */

    /* Animate the tabs, set initial width. */
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

    /* Shunt the status info (text on hover) over to accomodate tabs */
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
}
