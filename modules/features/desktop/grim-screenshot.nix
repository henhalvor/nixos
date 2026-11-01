# Grim Screenshot — screenshot tool (generic Wayland)
# Source: home/modules/desktop/screenshot/grim.nix
# Template B2: HM-only with screenshot wrapper script
{self, ...}: {
  flake.nixosModules.grimScreenshot = {...}: {
    home-manager.sharedModules = [self.homeModules.grimScreenshot];
  };

  flake.homeModules.grimScreenshot = {pkgs, ...}: let
    screenshotScript = pkgs.writeShellApplication {
      name = "screenshot";
      runtimeInputs = with pkgs; [grim slurp satty wl-clipboard coreutils libnotify];
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
          --edit)
            mkdir -p ~/Pictures/Screenshots
            grim -g "$(slurp)" - | satty --filename - \
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
    home.packages = [pkgs.grim pkgs.slurp pkgs.satty pkgs.wl-clipboard screenshotScript];
  };
}
