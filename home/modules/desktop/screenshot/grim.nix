{ config, lib, pkgs, ... }:
let
  screenshotScript = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [ grim slurp swappy coreutils libnotify ];
    text = ''
      case "''${1:-}" in
        --copy)
          grim -g "$(slurp)" - | wl-copy
          notify-send --expire-time=1500 "Screenshot" "Copied to clipboard"
          ;;
        --save)
          mkdir -p ~/Pictures/Screenshots
          FILE=~/Pictures/Screenshots/"$(date +%Y-%m-%d_%H-%M-%S)".png
          grim -g "$(slurp)" "$FILE"
          notify-send --expire-time=2000 "Screenshot" "Saved to $FILE"
          ;;
        --swappy)
          grim -g "$(slurp)" - | swappy -f -
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
    pkgs.grim
    pkgs.slurp
    pkgs.swappy
    pkgs.wl-clipboard
    screenshotScript
  ];
}
