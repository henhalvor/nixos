# Gaming — Steam, Gamemode, Wine, launchers
# Source: nixos/modules/gaming.nix
{...}: {
  flake.nixosModules.gaming = {pkgs, ...}: let
    titanfall2SteamLaunch = pkgs.writeShellScriptBin "titanfall2-steam-launch" ''
      set -euo pipefail

      log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}"
      mkdir -p "$log_dir"
      exec >> "$log_dir/titanfall2-steam-launch.log" 2>&1
      echo
      echo "[$(date --iso-8601=seconds)] titanfall2-steam-launch $*"

      if [ "$#" -eq 0 ]; then
        echo "Usage: titanfall2-steam-launch %command%" >&2
        exit 64
      fi

      export SDL_VIDEODRIVER="wayland,x11"
      export PULSE_LATENCY_MSEC="''${PULSE_LATENCY_MSEC:-60}"
      export PIPEWIRE_LATENCY="''${PIPEWIRE_LATENCY:-512/48000}"
      export PULSE_SOURCE="sunshine-sink.monitor"

      ${pkgs.pulseaudio}/bin/pactl set-card-profile bluez_card.24_C4_06_41_55_BE a2dp-sink || true

      exec ${pkgs.gamemode}/bin/gamemoderun "$@" \
        -fullscreen \
        -w 2560 -h 1440 \
        -refresh 144 \
        +sound_num_speakers 2 \
        +miles_occlusion 0 \
        +voice_modenable 0 \
        +voice_enabled 0 \
        +voice_forcemicrecord 0 \
        +voice_vox 0 \
        +sound_volume_voice 0 \
        +rankedplay_voice_enabled 0 \
        +sv_voiceenable 0
    '';
  in {
    programs.gamemode.enable = true;

    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      protontricks.enable = true;

      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];

      extraPackages = with pkgs; [
        gamescope
        gamemode
        mangohud
        libpulseaudio
        pipewire
      ];
    };

    environment.systemPackages = with pkgs; [
      gamescope
      mangohud
      protontricks
      titanfall2SteamLaunch
      wineWowPackages.staging
      winetricks
      heroic
      lutris
      mumble
      protonup-qt
      teamspeak3
      (prismlauncher.override {
        additionalPrograms = [ffmpeg];
        jdks = [
          graalvmPackages.graalvm-ce
          zulu8
          zulu17
          zulu
        ];
      })
    ];
  };
}
