{ config, lib, pkgs, userSettings, ... }:
let
  inherit (config.lib.stylix) colors;
  
  # Use Stylix wallpaper
  wallpaperPath = "${config.stylix.image}";

  sddm-astronaut = pkgs.sddm-astronaut.override {
    embeddedTheme = "black_hole";
    themeConfig = {
      # Screen dimensions
      ScreenWidth = "1920";
      ScreenHeight = "1080";

      # Font settings from Stylix
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

      # Text colors from Stylix
      HeaderTextColor = "#${colors.base0B}";  # Green accent
      DateTextColor = "#${colors.base0D}";    # Blue accent
      TimeTextColor = "#${colors.base0D}";    # Blue accent

      # Form background colors
      FormBackgroundColor = "rgba(${colors.base00-rgb-r}, ${colors.base00-rgb-g}, ${colors.base00-rgb-b}, 0.7)";
      BackgroundColor = "#${colors.base00}";
      DimBackgroundColor = "#${colors.base00}";

      # Input field colors
      LoginFieldBackgroundColor = "rgba(${colors.base01-rgb-r}, ${colors.base01-rgb-g}, ${colors.base01-rgb-b}, 0.8)";
      PasswordFieldBackgroundColor = "rgba(${colors.base01-rgb-r}, ${colors.base01-rgb-g}, ${colors.base01-rgb-b}, 0.8)";
      LoginFieldTextColor = "#${colors.base05}";
      PasswordFieldTextColor = "#${colors.base05}";
      UserIconColor = "#${colors.base0D}";
      PasswordIconColor = "#${colors.base0D}";

      PlaceholderTextColor = "#${colors.base03}";
      WarningColor = "#${colors.base08}";

      # Button colors
      LoginButtonTextColor = "#${colors.base00}";
      LoginButtonBackgroundColor = "#${colors.base0B}";
      SystemButtonsIconsColor = "#${colors.base0D}";
      SessionButtonTextColor = "#${colors.base0D}";
      VirtualKeyboardButtonTextColor = "#${colors.base0D}";

      # Dropdown colors
      DropdownTextColor = "#${colors.base05}";
      DropdownSelectedBackgroundColor = "rgba(${colors.base0D-rgb-r}, ${colors.base0D-rgb-g}, ${colors.base0D-rgb-b}, 0.2)";
      DropdownBackgroundColor = "rgba(${colors.base01-rgb-r}, ${colors.base01-rgb-g}, ${colors.base01-rgb-b}, 0.9)";

      # Highlight colors
      HighlightTextColor = "#${colors.base0D}";
      HighlightBackgroundColor = "rgba(${colors.base0D-rgb-r}, ${colors.base0D-rgb-g}, ${colors.base0D-rgb-b}, 0.2)";
      HighlightBorderColor = "#${colors.base0D}";

      # Hover colors
      HoverUserIconColor = "#${colors.base0C}";
      HoverPasswordIconColor = "#${colors.base0C}";
      HoverSystemButtonsIconsColor = "#${colors.base0C}";
      HoverSessionButtonTextColor = "#${colors.base0C}";
      HoverVirtualKeyboardButtonTextColor = "#${colors.base0C}";

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
