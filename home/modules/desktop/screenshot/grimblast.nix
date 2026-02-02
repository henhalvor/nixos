{ config, lib, pkgs, ... }:
let
  screenshotScript = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [ grimblast swappy coreutils libnotify ];
    text = ''
      case "''${1:-}" in
        --copy)
          grimblast copy area
          notify-send --expire-time=1500 "Screenshot" "Copied to clipboard"
          ;;
        --save)
          mkdir -p ~/Pictures/Screenshots
          FILE=~/Pictures/Screenshots/"$(date +%Y-%m-%d_%H-%M-%S)".png
          grimblast save area "$FILE"
          notify-send --expire-time=2000 "Screenshot" "Saved to $FILE"
          ;;
        --swappy)
          grimblast save area - | swappy -f -
          ;;
        *)
          echo "Usage: screenshot [--copy|--save|--swappy]"
          exit 1
          ;;
      esac
    '';
  };
in {
  home.packages = [
    pkgs.grimblast
    pkgs.grim
    pkgs.slurp
    pkgs.swappy
    screenshotScript
  ];
}
