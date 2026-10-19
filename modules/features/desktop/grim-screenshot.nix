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
      runtimeInputs = with pkgs; [grim slurp swappy coreutils libnotify];
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
            mkdir -p ~/Pictures/Screenshots
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
    home.packages = [pkgs.grim pkgs.slurp pkgs.swappy pkgs.wl-clipboard screenshotScript];

    # Save edited screenshots alongside niri's, using the same naming scheme
    xdg.configFile."swappy/config".text = ''
      [Default]
      save_dir=$HOME/Pictures/Screenshots
      save_filename_format=Screenshot from %Y-%m-%d %H-%M-%S.png
    '';
  };
}
