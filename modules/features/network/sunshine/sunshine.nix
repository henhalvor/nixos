# Sunshine remote game-streaming server.
#
# The display selection is deliberately declarative. Niri creates the stable
# `sunshine` virtual output, and Sunshine captures that output through the
# Wayland screencopy backend.
{ ... }:
{
  flake.nixosModules.sunshine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      niri = lib.getExe config.programs.niri.package;

      focusSunshine = pkgs.writeShellScriptBin "sunshine-focus" ''
        set -eu

        state_file="''${XDG_RUNTIME_DIR}/sunshine-previous-output"
        ${niri} msg --json focused-output \
          | ${pkgs.jq}/bin/jq -r '.name' > "$state_file"
        ${niri} msg action focus-workspace 10
        ${niri} msg action focus-monitor sunshine
      '';

      restoreSunshineFocus = pkgs.writeShellScriptBin "sunshine-restore-focus" ''
        set -eu

        state_file="''${XDG_RUNTIME_DIR}/sunshine-previous-output"
        if [ -s "$state_file" ]; then
          output="$(${pkgs.coreutils}/bin/cat "$state_file")"
          case "$output" in
            HDMI-A-1|DP-1|sunshine)
              ${niri} msg action focus-monitor "$output"
              ;;
          esac
          ${pkgs.coreutils}/bin/rm -f "$state_file"
        fi
      '';
    in
    {
      sops.secrets = {
        "sunshine-username" = {
          sopsFile = ../../../../secrets/workstation-services.yaml;
          key = "SUNSHINE_USERNAME";
          owner = "henhal";
          mode = "0400";
        };
        "sunshine-password" = {
          sopsFile = ../../../../secrets/workstation-services.yaml;
          key = "SUNSHINE_PASSWORD";
          owner = "henhal";
          mode = "0400";
        };
      };

      services.sunshine = {
        enable = true;
        autoStart = true;
        capSysAdmin = true;
        openFirewall = false;

        settings = {
          capture = "wlr";
          # Sunshine's Linux/Wayland output_name uses the numeric display ID.
          # Niri reports the virtual sunshine output as display 2.
          output_name = "2";
          sunshine_name = "workstation";
          # Allow Android clients to emulate Super/Mod with Right Alt.
          key_rightalt_to_key_win = "enabled";
        };

        applications = {
          apps = [
            {
              name = "Desktop (Sunshine virtual display)";
              "image-path" = "desktop.png";
              "prep-cmd" = [
                {
                  do = lib.getExe focusSunshine;
                  undo = lib.getExe restoreSunshineFocus;
                }
              ];
            }
          ];
        };
      };

      # Sunshine stores the web password as a salted hash in its state file.
      # Apply the SOPS-backed credentials through Sunshine's supported writer
      # before the user service starts, without embedding either value in Nix.
      systemd.user.services.sunshine.preStart = ''
        set -euo pipefail
        username="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."sunshine-username".path})"
        password="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets."sunshine-password".path})"
        ${lib.getExe config.services.sunshine.package} --creds "$username" "$password"
        unset username password
      '';

      environment.systemPackages = with pkgs; [
        libva-utils
        cudatoolkit
      ];

      # Sunshine listens on all addresses, but the firewall admits its ports
      # only through the private Tailscale interface.
      networking.firewall.interfaces.tailscale0 = {
        allowedTCPPorts = [
          47984
          47989
          47990
          48010
        ];
        allowedUDPPorts = [
          47998
          47999
          48000
          48002
          48010
        ];
      };

    };
}
