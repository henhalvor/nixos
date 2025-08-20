{ config, lib, pkgs, ... }: {
  # First, we need to install hyprlock
  home.packages = [ pkgs.hyprlock ];

  # Create the configuration file for hyprlock
  xdg.configFile."hypr/hyprlock.conf".text = ''
    # Base colors for background and surface elements
    $base = rgb(24, 25, 38)        # Base background color
    $surface0 = rgb(54, 58, 79)    # Surface color for elements
    $overlay0 = rgb(110, 115, 141) # Muted foreground color
    $text = rgb(202, 211, 245)     # Main text color
    $lavender = rgb(183, 189, 248) # Accent color for highlights
    $red = rgb(237, 135, 150)      # For error states or emphasis

    # The general configuration section specifies core settings
    general {
        disable_loading_bar = false
        hide_cursor = true
        grace = 0
    }

    # The background section configures the background appearance
    background {
        monitor =  # Leave this empty for all monitors
        path = ~/.dotfiles/assets/wallpapers/catppuccin_landscape.png #screenshot   # Use a screenshot as background
        blur_passes = 2    # How many blur passes to perform
        blur_size = 7      # Scale of the gaussian blur
        noise = 0.0117     # Add noise to blur
        contrast = 0.8916  # Adjust contrast
        brightness = 0.8172  # Adjust brightness
    }

    # The input field styling
     input-field {
        monitor =
        size = 250, 50          # Slightly wider for better visual balance
        outline_thickness = 2    # Thin outline for elegance
        dots_size = 0.2
        dots_spacing = 0.64
        dots_center = true
        dots_rounding = 2       # Rounded dots to match Catppuccin's style
        
        # Using our Catppuccin Macchiato colors
        outer_color = $surface0         # Subtle border using surface color
        inner_color = $base            # Dark base for the input background
        font_color = $text            # Clear, readable text color
        fade_on_empty = true
        placeholder_text = <i>Password...</i>    # Italic placeholder for style
        hide_input = false
        rounding = 8            # Soft rounding for modern look
        
        # Adding a check mark using Catppuccin colors that appears on keypress
        check_color = $lavender
        
        # Error state using Catppuccin's red
        fail_color = $red
        fail_text = <i>Invalid password!</i>
        
        position = 0, -20
        halign = center
        valign = center
      }

    # You can add additional labels for time/date/greetings
    label {
        monitor =
        text = cmd[update:1000] echo "$(date "+%H:%M")"
        color = $text
        font_size = 64
        font_family = Hack Nerd Font
        position = 0, -140
        halign = center
        valign = center
    }
  '';
}
