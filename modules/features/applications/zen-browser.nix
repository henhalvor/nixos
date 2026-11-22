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

  flake.homeModules.zenBrowser = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;

    # Netflix judges decoder performance by droppedVideoFrames. When Zen is on
    # a hidden niri workspace nothing is presented, so every decoded frame
    # counts as "dropped" and Netflix downgrades 1080p -> 720p -> 540p (with an
    # audio hiccup at each switch). This hides that counter from the page.
    netflixKeepQuality = let
      id = "netflix-keep-quality@local";
      manifest = builtins.toJSON {
        manifest_version = 3;
        name = "Netflix: keep quality when hidden";
        version = "1.0";
        browser_specific_settings.gecko.id = id;
        host_permissions = ["https://www.netflix.com/*"];
        content_scripts = [
          {
            matches = ["https://www.netflix.com/*"];
            js = ["content.js"];
            run_at = "document_start";
            world = "MAIN";
            all_frames = true;
          }
        ];
      };
      contentJs = ''
        (() => {
          const proto = HTMLVideoElement.prototype;
          const orig = proto.getVideoPlaybackQuality;
          if (!orig) return;
          proto.getVideoPlaybackQuality = function () {
            const q = orig.call(this);
            return {
              creationTime: q.creationTime,
              totalVideoFrames: q.totalVideoFrames,
              droppedVideoFrames: 0,
              corruptedVideoFrames: q.corruptedVideoFrames,
            };
          };
        })();
      '';
      xpi =
        pkgs.runCommand "netflix-keep-quality.xpi" {
          nativeBuildInputs = [pkgs.zip];
          passAsFile = ["manifest" "contentJs"];
          inherit manifest contentJs;
        } ''
          mkdir ext
          cp "$manifestPath" ext/manifest.json
          cp "$contentJsPath" ext/content.js
          (cd ext && zip -X -q "$out" manifest.json content.js)
        '';
    in {inherit id xpi;};

    # Policies must go on the *unwrapped* package: the zen binary resolves its
    # app dir to the unwrapped store path, so a policies.json written by
    # wrapFirefox (extraPolicies/extraPrefs) is never read.
    zen =
      pkgs.wrapFirefox
      (inputs.zen-browser.packages.${system}.beta-unwrapped.override {
        policies = {
          ExtensionSettings.${netflixKeepQuality.id} = {
            installation_mode = "force_installed";
            install_url = "file://${netflixKeepQuality.xpi}";
          };
          # Zen is built without MOZ_REQUIRE_SIGNING, so this lets the local
          # (unsigned) extension above load.
          Preferences."xpinstall.signatures.required" = {
            Value = false;
            Status = "locked";
          };
        };
      })
      {icon = "zen-browser";};
  in {
    home.packages = [zen];

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
