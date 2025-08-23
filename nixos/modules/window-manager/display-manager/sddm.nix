{ pkgs, lib, config, userSettings, ... }:
let

  # For same wallpaper as stylix theme
  # selectedWallpaper =
  #   userSettings.stylixTheme.wallpaper or "catppuccin_landscape.png";

  selectedWallpaper = "futuristic-background-with-green-letters.jpg";

  assetsDir = ../../../../assets;
  wallpaperPath = "${assetsDir}/wallpapers/${selectedWallpaper}";

  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
    themeConfig = {
      # Screen dimensions
      ScreenWidth = "1920";
      ScreenHeight = "1080";

      # Font settings
      Font = config.stylix.fonts.sansSerif.name;
      FontSize = "12";

      RoundCorners = "20";

      # Background settings
      BackgroundPlaceholder = "${wallpaperPath}";
      Background = "${wallpaperPath}";
      BackgroundSpeed = "1.0";
      PauseBackground = "";
      CropBackground = "true";
      BackgroundHorizontalAlignment = "center";
      BackgroundVerticalAlignment = "center";
      DimBackground = "0.2";

      # Text colors - Matrix green theme
      HeaderTextColor = "#00ff41"; # Bright Matrix green
      DateTextColor = "#00ff41";
      TimeTextColor = "#00ff41";

      # Form background colors - Dark with transparency
      FormBackgroundColor = "rgba(0, 0, 0, 0.7)";
      BackgroundColor = "#000000";
      DimBackgroundColor = "#000000";

      # Input field colors
      LoginFieldBackgroundColor = "rgba(0, 20, 0, 0.8)";
      PasswordFieldBackgroundColor = "rgba(0, 20, 0, 0.8)";
      LoginFieldTextColor = "#00ff41";
      PasswordFieldTextColor = "#00ff41";
      UserIconColor = "#00ff41";
      PasswordIconColor = "#00ff41";

      PlaceholderTextColor = "#008f11"; # Darker green for placeholders
      WarningColor = "#ff4444"; # Red for warnings

      # Button colors
      LoginButtonTextColor = "#000000";
      LoginButtonBackgroundColor = "#00ff41";
      SystemButtonsIconsColor = "#00ff41";
      SessionButtonTextColor = "#00ff41";
      VirtualKeyboardButtonTextColor = "#00ff41";

      # Dropdown colors
      DropdownTextColor = "#00ff41";
      DropdownSelectedBackgroundColor = "rgba(0, 255, 65, 0.2)";
      DropdownBackgroundColor = "rgba(0, 20, 0, 0.9)";

      # Highlight colors
      HighlightTextColor = "#00ff41";
      HighlightBackgroundColor = "rgba(0, 255, 65, 0.2)";
      HighlightBorderColor = "#00ff41";

      # Hover colors - Slightly brighter green
      HoverUserIconColor = "#44ff77";
      HoverPasswordIconColor = "#44ff77";
      HoverSystemButtonsIconsColor = "#44ff77";
      HoverSessionButtonTextColor = "#44ff77";
      HoverVirtualKeyboardButtonTextColor = "#44ff77";

      # Blur effects
      PartialBlur = "true";
      BlurMax = "25";
      Blur = "1.5";

      # Form settings
      HaveFormBackground = "false";
      FormPosition = "left";
    };
  };
in {
  environment.systemPackages = [ sddm-astronaut ];

  services = {
    xserver.enable = true;

    displayManager = {
      sddm = {
        wayland.enable = true;
        enable = true;
        package = pkgs.kdePackages.sddm;

        theme = "sddm-astronaut-theme";

        extraPackages = [ sddm-astronaut ];

        # Not working since sddm is using wayland and not x11
        setupScript = ''
          ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-A-1 --primary --mode 2560x1440 --pos 1080x0 --output DP-1 --mode 1080x1920 --pos 0x0 --rotate left
        '';

      };
      autoLogin = {
        enable = false;
        user = "henhal";
      };
    };
  };

}
