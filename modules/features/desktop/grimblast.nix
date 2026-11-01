# Grimblast — screenshot tool (Hyprland-native)
# Source: home/modules/desktop/screenshot/grimblast.nix
# Template B2: HM-only with screenshot wrapper script
{self, ...}: {
  flake.nixosModules.grimblast = {...}: {
    home-manager.sharedModules = [self.homeModules.grimblast];
  };

  flake.homeModules.grimblast = {pkgs, ...}: let
    screenshotScript = pkgs.writeShellApplication {
      name = "screenshot";
      runtimeInputs = with pkgs; [grimblast satty wl-clipboard coreutils libnotify];
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
          --edit)
            mkdir -p ~/Pictures/Screenshots
            grimblast save area - | satty --filename - \
              --output-filename "$HOME/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png" \
              --copy-command wl-copy \
              --early-exit
            ;;
          *)
            echo "Usage: screenshot [--copy|--save|--edit]"
            exit 1
            ;;
        esac
      '';
    };
  in {
    home.packages = [pkgs.grimblast pkgs.grim pkgs.slurp pkgs.satty screenshotScript];
  };
}
