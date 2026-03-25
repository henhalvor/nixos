{lib}: rec {
  # Per-session defaults - what each session uses by default
  sessionDefaults = {
    hyprland = {
      bar = "hyprpanel";
      lock = "hyprlock";
      idle = "hypridle";
      notifications = "none";
      launcher = "rofi";
      dm = "sddm";
      clipboard = "clipman";
      screenshotTool = "grimblast";
      trayApplets = "wayland";
      nightLight = "gammastep";
      logout = "wlogout";
      shell = null;
    };
    niri = {
      bar = "waybar";
      lock = "swaylock";
      idle = "swayidle";
      notifications = "mako";
      launcher = "rofi";
      dm = "sddm";
      clipboard = "clipman";
      screenshotTool = "grim";
      trayApplets = "wayland";
      nightLight = "gammastep";
      logout = "wlogout";
      shell = null;
    };
    sway = {
      bar = "waybar";
      lock = "swaylock";
      idle = "swayidle";
      notifications = "mako";
      launcher = "rofi";
      dm = "sddm";
      clipboard = "clipman";
      screenshotTool = "grim";
      trayApplets = "wayland";
      nightLight = "gammastep";
      logout = "wlogout";
      shell = null;
    };
    gnome = {
      bar = "none";
      lock = "loginctl";
      idle = "none";
      notifications = "none";
      launcher = "none";
      dm = "gdm";
      clipboard = "none";
      screenshotTool = "none";
      trayApplets = "none";
      nightLight = "none";
      logout = "none";
      shell = null;
    };
    none = {
      bar = "none";
      lock = "none";
      idle = "none";
      notifications = "none";
      launcher = "none";
      dm = "none";
      clipboard = "none";
      screenshotTool = "none";
      trayApplets = "none";
      nightLight = "none";
      logout = "none";
      shell = null;
    };
  };

  # Resolve null values to session defaults
  resolveDesktop = desktop: let
    session = desktop.session or "none";
    defaults = sessionDefaults.${session};
    shell = desktop.shell or null;
    # When a desktop shell is active it manages bar, notifications, and logout
    shellActive = shell != null;
  in
    desktop
    // {
      shell = shell;
      bar =
        if shellActive
        then "none"
        else if desktop.bar or null != null
        then desktop.bar
        else defaults.bar;
      lock =
        if desktop.lock or null != null
        then desktop.lock
        else defaults.lock;
      idle =
        if desktop.idle or null != null
        then desktop.idle
        else defaults.idle;
      notifications =
        if shellActive
        then "none"
        else if desktop.notifications or null != null
        then desktop.notifications
        else defaults.notifications;
      launcher =
        if desktop.launcher or null != null
        then desktop.launcher
        else if shellActive
        then "none"
        else defaults.launcher;
      clipboard =
        if desktop.clipboard or null != null
        then desktop.clipboard
        else defaults.clipboard;
      screenshotTool =
        if desktop.screenshotTool or null != null
        then desktop.screenshotTool
        else defaults.screenshotTool;
      trayApplets =
        if desktop.trayApplets or null != null
        then desktop.trayApplets
        else defaults.trayApplets;
      nightLight =
        if desktop.nightLight or null != null
        then desktop.nightLight
        else defaults.nightLight;
      logout =
        if shellActive
        then "none"
        else if desktop.logout or null != null
        then desktop.logout
        else defaults.logout;
      dm = defaults.dm;
    };
}
