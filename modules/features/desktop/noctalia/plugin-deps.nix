# Runtime dependencies for Noctalia v5 plugins.
#
# Plugins are installed at runtime from the TOML config (v5/<host>.toml), so
# Nix does not know what binaries they shell out to. Each plugin lists its
# requirements under `dependencies` in its plugin.toml; add the ones the
# system does not already provide here.
#
# demencia89/androidconnect needs:
#   python3, adb, ffmpeg, busctl, avahi-browse, xdg-open  -> already on the system
#   scrcpy, fuser, qrencode, xdg-user-dir                 -> added below
#   /dev/video10 v4l2loopback (embedded preview)          -> system module below
{ self, ... }:
{
  # System-level plugin deps. Imported by the noctalia module; only active
  # with v5, where it also pulls in the home-manager deps below.
  flake.nixosModules.noctalia-plugin-deps =
    { config, lib, ... }:
    lib.mkIf (config.my.noctalia.version == "v5") {
      # androidconnect: scrcpy streams into this virtual camera and the panel
      # reads the embedded preview from it. Options follow the plugin README.
      # The node is root:video 0660, so users need the video group.
      boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
      boot.kernelModules = [ "v4l2loopback" ];
      boot.extraModprobeConfig = ''
        options v4l2loopback video_nr=10 card_label="scrcpy-panel" exclusive_caps=0
      '';

      home-manager.sharedModules = [ self.homeModules.noctalia-plugin-deps ];
    };

  flake.homeModules.noctalia-plugin-deps =
    { pkgs, ... }:
    let
      # SDL falls back to its software renderer under niri/Wayland, which
      # creates a window that never gets shown. Default to OpenGL ES for
      # scrcpy only; --render-driver still overrides it.
      scrcpy = pkgs.symlinkJoin {
        name = "scrcpy-gles";
        paths = [ pkgs.scrcpy ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/scrcpy --set-default SDL_RENDER_DRIVER opengles2
        '';
      };

      # Reconnect wireless adb to an already-paired phone. The phone's connect
      # port changes whenever wireless debugging restarts, so discover it via
      # mDNS. Reports through notifications since it runs from the launcher.
      adb-phone = pkgs.writeShellApplication {
        name = "adb-phone";
        runtimeInputs = with pkgs; [
          android-tools
          avahi
          gawk
          libnotify
        ];
        text = ''
          notify() { notify-send -a "adb-phone" -i phone "$@" || true; echo "$*"; }

          target=$(avahi-browse -rpt _adb-tls-connect._tcp 2>/dev/null \
            | awk -F';' '/^=/ && $3 == "IPv4" && !found { print $8 ":" $9; found = 1 }')

          if [ -z "$target" ]; then
            notify "No phone found" "Turn on Wireless debugging and use the same Wi-Fi."
            exit 1
          fi

          if out=$(adb connect "$target" 2>&1) && [[ "$out" == *connected* ]]; then
            notify "Phone connected" "$target"
          else
            notify "adb connect failed" "$target: $out"
            exit 1
          fi
        '';
      };
    in
    {
      xdg.desktopEntries.adb-phone = {
        name = "Connect Phone (adb)";
        genericName = "Wireless adb";
        comment = "Reconnect wireless adb to the paired Android phone";
        exec = "${adb-phone}/bin/adb-phone";
        icon = "phone";
        terminal = false;
        categories = [ "Utility" ];
      };

      home.packages = with pkgs; [
        adb-phone
        scrcpy # androidconnect: screen mirroring (wrapped, see above)
        psmisc # androidconnect: fuser
        qrencode # androidconnect: pairing QR codes
        xdg-user-dirs # androidconnect: xdg-user-dir
      ];
    };
}
