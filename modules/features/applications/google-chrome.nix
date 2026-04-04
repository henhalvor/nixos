# Google Chrome — browser with Gmail PWA + incognito desktop entry
# Source: home/modules/applications/google-chrome.nix
# Template B2: HM-only
{ self, ... }: {
  flake.nixosModules.googleChrome = { ... }: {
    home-manager.sharedModules = [ self.homeModules.googleChrome ];
  };

  flake.homeModules.googleChrome = { pkgs, ... }: let
    gmail = pkgs.writeShellScriptBin "gmail" ''
      exec ${pkgs.google-chrome}/bin/google-chrome-stable \
        --app=https://mail.google.com \
        --no-default-browser-check \
        --force-dark-mode \
        --enable-features=WebContentsForceDark \
        --no-first-run
    '';

    toggleGmail = pkgs.writeShellScriptBin "toggle-gmail" ''
      CLASS="chrome-mail.google.com__-Default"
      GMAIL_PROCESS_PATTERN='google-chrome.*--app=https://mail.google.com'

      if [ -n "''${NIRI_SOCKET-}" ] || [ "''${XDG_CURRENT_DESKTOP-}" = "niri" ]; then
        if ! pgrep -fa "$GMAIL_PROCESS_PATTERN" >/dev/null; then
          gmail &
          sleep 0.5
        fi
        niri msg action focus-workspace gmail
        exit 0
      fi

      # Launch Gmail if no window exists yet
      if ! hyprctl clients | grep -q "class: $CLASS"; then
        gmail &
        for i in $(seq 1 10); do
          sleep 0.5
          hyprctl clients | grep -q "class: $CLASS" && break
        done
      fi

      hyprctl dispatch togglespecialworkspace gmail
    '';
  in {
    home.packages = [ pkgs.google-chrome gmail toggleGmail ];

    xdg.desktopEntries."google-chrome-incognito" = {
      name = "Google Chrome (Incognito)";
      comment = "Access the internet (Incognito Mode)";
      exec = "${pkgs.google-chrome}/bin/google-chrome-stable --incognito %U";
      icon = "google-chrome";
      terminal = false;
      type = "Application";
      categories = [ "Network" "WebBrowser" ];
    };
  };
}
