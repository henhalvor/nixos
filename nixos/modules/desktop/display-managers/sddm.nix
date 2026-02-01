{ config, lib, pkgs, userSettings, ... }:
let
  # Use Stylix wallpaper
  wallpaperPath = "${config.stylix.image}";

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
      BackgroundPlaceholder = wallpaperPath;
      Background = wallpaperPath;
      BackgroundSpeed = "1.0";
      PauseBackground = "";
      CropBackground = "true";
      BackgroundHorizontalAlignment = "center";
      BackgroundVerticalAlignment = "center";
      DimBackground = "0.2";

      # Text colors - Matrix green theme
      HeaderTextColor = "#00ff41";
      DateTextColor = "#00ff41";
      TimeTextColor = "#00ff41";

      # Form background colors
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

      PlaceholderTextColor = "#008f11";
      WarningColor = "#ff4444";

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

      # Hover colors
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

  services.xserver.enable = true;

  services.displayManager = {
    sddm = {
      wayland.enable = true;
      enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      extraPackages = [ sddm-astronaut ];
    };
    autoLogin = {
      enable = false;
      user = userSettings.username;
    };
  };
}
